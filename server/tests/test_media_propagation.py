import asyncio
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy import select

import server.database as database_module
from server.main import app
from server.models.orm import Base, Piece, MediaAsset
from server.config import settings

async def _create_schema(engine) -> None:
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

@pytest.fixture()
def test_client(tmp_path, monkeypatch):
    test_db_path = tmp_path / "azmusic_test.db"
    test_storage_path = tmp_path / "storage"
    test_engine = create_async_engine(
        f"sqlite+aiosqlite:///{test_db_path.as_posix()}",
        echo=False,
    )
    session_factory = async_sessionmaker(
        bind=test_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async def override_get_db():
        async with session_factory() as session:
            yield session

    asyncio.run(_create_schema(test_engine))

    monkeypatch.setattr(database_module, "engine", test_engine)
    monkeypatch.setattr(database_module, "async_session", session_factory)
    monkeypatch.setattr(settings, "storage_path", test_storage_path)
    app.dependency_overrides[database_module.get_db] = override_get_db

    with TestClient(app) as client:
        yield client, tmp_path

    app.dependency_overrides.clear()
    asyncio.run(test_engine.dispose())


def test_youtube_media_propagation_and_retroactive_sync(test_client) -> None:
    client, tmp_path = test_client

    # Create a fake audio file on disk to satisfy the downloader and sync check
    fake_audio = tmp_path / "fake_audio.mp3"
    fake_audio.write_bytes(b"fake audio data")

    # 1. Create two pieces with matching title and composer for different students
    p1_resp = client.post(
        "/api/v1/pieces/",
        json={"title": "Minuet in G", "composer": "J.S. Bach", "file_name": "minuet1.pdf"}
    )
    assert p1_resp.status_code == 200
    p1_id = p1_resp.json()["id"]

    p2_resp = client.post(
        "/api/v1/pieces/",
        json={"title": "Minuet in G", "composer": "J.S. Bach", "file_name": "minuet2.pdf"}
    )
    assert p2_resp.status_code == 200
    p2_id = p2_resp.json()["id"]

    # 2. Stage a candidate on Piece 1 with the local file path populated
    async def seed_data():
        async with database_module.async_session() as session:
            candidate = MediaAsset(
                id="candidate-asset-1",
                piece_id=p1_id,
                asset_type="youtube_candidate",
                youtube_video_id="video-12345",
                thumbnail_url="http://thumb",
                is_approved=False,
                status="staged",
                local_file_path=str(fake_audio)
            )
            session.add(candidate)
            await session.commit()
    
    asyncio.run(seed_data())

    # 3. Verify it is staged for Piece 1
    candidates_resp = client.get(f"/api/v1/pieces/{p1_id}/candidates")
    assert candidates_resp.status_code == 200
    candidates = candidates_resp.json()
    assert len(candidates) == 1
    assert candidates[0]["youtube_video_id"] == "video-12345"

    # 4. Push / approve the candidate on Piece 1
    push_resp = client.post(f"/api/v1/media/candidate-asset-1/push")
    assert push_resp.status_code == 200

    # 5. Verify it propagated to Piece 2 automatically!
    sync_resp = client.get(
        f"/api/v1/pieces/{p2_id}/sync-delta",
        params={"client_last_sync": "1970-01-01T00:00:00Z"}
    )
    assert sync_resp.status_code == 200
    sync_data = sync_resp.json()
    assert len(sync_data["media_attachments"]) == 1
    assert sync_data["media_attachments"][0]["youtube_video_id"] == "video-12345"


def test_retroactive_sync_propagation(test_client) -> None:
    client, tmp_path = test_client

    # Create a fake audio file on disk
    fake_audio = tmp_path / "fake_elise.mp3"
    fake_audio.write_bytes(b"fake elise audio data")

    # Create two pieces with matching title/composer
    p1_resp = client.post(
        "/api/v1/pieces/",
        json={"title": "Für Elise", "composer": "Beethoven", "file_name": "elise1.pdf"}
    )
    p1_id = p1_resp.json()["id"]

    p2_resp = client.post(
        "/api/v1/pieces/",
        json={"title": "Für Elise", "composer": "Beethoven", "file_name": "elise2.pdf"}
    )
    p2_id = p2_resp.json()["id"]

    # Directly insert an approved media asset on Piece 1 (simulate pre-existing approved asset)
    async def seed_approved():
        async with database_module.async_session() as session:
            asset = MediaAsset(
                id="approved-asset-elise",
                piece_id=p1_id,
                asset_type="youtube_candidate",
                youtube_video_id="video-elise",
                thumbnail_url="http://thumb-elise",
                is_approved=True,
                status="approved",
                local_file_path=str(fake_audio)
            )
            session.add(asset)
            await session.commit()

    asyncio.run(seed_approved())

    # Call retroactive sync endpoint
    sync_resp = client.post("/api/v1/media/retroactive-sync")
    assert sync_resp.status_code == 200
    res_data = sync_resp.json()
    assert res_data["propagated_assets_count"] == 1

    # Verify Piece 2 now has the approved media asset
    p2_sync = client.get(
        f"/api/v1/pieces/{p2_id}/sync-delta",
        params={"client_last_sync": "1970-01-01T00:00:00Z"}
    )
    assert p2_sync.status_code == 200
    attachments = p2_sync.json()["media_attachments"]
    assert len(attachments) == 1
    assert attachments[0]["youtube_video_id"] == "video-elise"

