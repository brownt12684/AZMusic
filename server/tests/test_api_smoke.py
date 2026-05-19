import asyncio

import pytest
import server.database as database_module
import server.main as main_module
from fastapi.testclient import TestClient
from server.config import settings
from server.main import app
from server.models.orm import Base
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine


async def _create_schema(engine) -> None:
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)


@pytest.fixture()
def api_client(tmp_path, monkeypatch):
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
    monkeypatch.setattr(main_module, "engine", test_engine)
    monkeypatch.setattr(settings, "storage_path", test_storage_path)
    app.dependency_overrides[database_module.get_db] = override_get_db

    with TestClient(app) as client:
        yield client, test_storage_path

    app.dependency_overrides.clear()
    asyncio.run(test_engine.dispose())


def test_api_route_groups_match_documentation(api_client) -> None:
    client, _ = api_client

    assert client.get("/api/v1/").status_code == 404
    assert client.get("/api/v1/pieces/").status_code == 200
    assert client.get("/api/v1/review/").status_code == 200
    assert client.get("/api/v1/jobs/").status_code == 200


def test_piece_detail_smoke_flow(api_client) -> None:
    client, storage_path = api_client

    create_piece = client.post(
        "/api/v1/pieces/",
        json={
            "title": "Suzuki Book 1",
            "composer": "Shinichi Suzuki",
            "file_name": "suzuki_book_1.pdf",
        },
    )
    assert create_piece.status_code == 200
    piece = create_piece.json()
    piece_id = piece["id"]
    assert piece["status"] == "imported"

    create_history_draft = client.post(
        f"/api/v1/pieces/{piece_id}/history_drafts",
        json={
            "content": "Family note for practice history.",
            "provenance": "manual",
        },
    )
    assert create_history_draft.status_code == 200

    upload_media = client.post(
        f"/api/v1/pieces/{piece_id}/media",
        data={"asset_type": "scan"},
        files={"file": ("practice_scan.jpg", b"fake-image-bytes", "image/jpeg")},
    )
    assert upload_media.status_code == 200

    detail_response = client.get(f"/api/v1/pieces/{piece_id}")
    assert detail_response.status_code == 200
    detail = detail_response.json()
    assert detail["file_name"] == "suzuki_book_1.pdf"
    assert len(detail["history_drafts"]) == 1
    assert len(detail["media_assets"]) == 1
    assert (
        storage_path / "media" / piece_id / f"{detail['media_assets'][0]['id']}.jpg"
    ).exists()


def test_review_job_and_sync_smoke_flow(api_client) -> None:
    client, _ = api_client

    piece_response = client.post(
        "/api/v1/pieces/",
        json={
            "title": "Wohlfahrt Etude",
            "file_name": "wohlfahrt_etude.pdf",
        },
    )
    assert piece_response.status_code == 200
    piece_id = piece_response.json()["id"]

    review_response = client.post(
        "/api/v1/review/",
        json={
            "piece_id": piece_id,
            "item_type": "piece_history",
            "title": "Confirm practice note",
            "description": "Check the imported family note before approval.",
        },
    )
    assert review_response.status_code == 200
    review_item = review_response.json()
    assert review_item["status"] == "pending"

    approve_response = client.post(
        f"/api/v1/review/{review_item['id']}",
        json={"action": "approve"},
    )
    assert approve_response.status_code == 200
    assert approve_response.json()["status"] == "approved"

    piece_detail = client.get(f"/api/v1/pieces/{piece_id}")
    assert piece_detail.status_code == 200
    assert piece_detail.json()["status"] == "approved"

    job_response = client.post(
        "/api/v1/jobs/trigger",
        json={"job_type": "ocr", "piece_id": piece_id},
    )
    assert job_response.status_code == 200
    job = job_response.json()
    assert job["status"] == "queued"

    update_job_response = client.patch(
        f"/api/v1/jobs/{job['id']}",
        json={"status": "running", "progress": 50.0},
    )
    assert update_job_response.status_code == 200
    assert update_job_response.json()["progress"] == 50.0

    upload_sync = client.post(
        "/api/v1/sync/surface-book/upload",
        json={"pending_uploads": 1},
    )
    assert upload_sync.status_code == 200
    assert upload_sync.json()["pending_uploads"] == 1

    download_sync = client.post(
        "/api/v1/sync/surface-book/download",
        json={"pending_downloads": 2},
    )
    assert download_sync.status_code == 200
    assert download_sync.json()["pending_downloads"] == 2

    sync_state = client.get("/api/v1/sync/surface-book")
    assert sync_state.status_code == 200
    assert sync_state.json()["pending_uploads"] == 1
    assert sync_state.json()["pending_downloads"] == 2


def test_pdf_import_processing_and_approval_flow(api_client) -> None:
    client, storage_path = api_client

    import_response = client.post(
        "/api/v1/pieces/import",
        data={
            "title": "Canon in D",
            "composer": "Pachelbel",
        },
        files={
            "file": ("canon_in_d.pdf", b"%PDF-1.4\n%AZMusic test pdf\n", "application/pdf")
        },
    )
    assert import_response.status_code == 200
    piece = import_response.json()
    piece_id = piece["id"]

    piece_detail = client.get(f"/api/v1/pieces/{piece_id}")
    assert piece_detail.status_code == 200
    detail = piece_detail.json()
    assert detail["status"] == "review_pending"
    assert detail["file_name"] == "canon_in_d.pdf"
    assert len(detail["score_versions"]) == 3
    assert detail["score_versions"][0]["is_default"] is True

    review_queue = client.get("/api/v1/review/")
    assert review_queue.status_code == 200
    review_items = review_queue.json()
    review_item = next(item for item in review_items if item["piece_id"] == piece_id)
    assert review_item["item_type"] == "score_candidate"
    assert review_item["candidate_data"]["raw_file_url"].endswith("/file")
    assert review_item["candidate_data"]["rendered_file_url"].endswith("/file")
    assert review_item["candidate_data"]["canonical_file_url"].endswith("/file")

    raw_file_response = client.get(review_item["candidate_data"]["raw_file_url"])
    rendered_file_response = client.get(review_item["candidate_data"]["rendered_file_url"])
    canonical_file_response = client.get(review_item["candidate_data"]["canonical_file_url"])
    assert raw_file_response.status_code == 200
    assert rendered_file_response.status_code == 200
    assert canonical_file_response.status_code == 200

    piece_storage_dir = storage_path / "pieces" / piece_id
    assert (piece_storage_dir / "raw_source.pdf").exists()
    assert (piece_storage_dir / "candidate.musicxml").exists()
    assert (piece_storage_dir / "candidate_review.pdf").exists()

    jobs = client.get("/api/v1/jobs/")
    assert jobs.status_code == 200
    job = next(job for job in jobs.json() if job["piece_id"] == piece_id)
    assert job["status"] == "succeeded"

    approve_response = client.post(
        f"/api/v1/review/{review_item['id']}",
        json={"action": "approve"},
    )
    assert approve_response.status_code == 200
    assert approve_response.json()["status"] == "approved"

    push_response = client.post(
        f"/api/v1/pieces/{piece_id}/push",
        json={"profile_ids": ["student-alyse"]},
    )
    assert push_response.status_code == 200
    assert push_response.json()["visible_to_profile_ids"] == ["student-alyse"]

    assigned_pieces = client.get("/api/v1/pieces/assigned/student-alyse")
    assert assigned_pieces.status_code == 200
    assigned_piece = next(item for item in assigned_pieces.json() if item["id"] == piece_id)
    assert assigned_piece["library_status"] == "ready"
    assert assigned_piece["visible_to_profile_ids"] == ["student-alyse"]

    approved_detail = client.get(f"/api/v1/pieces/{piece_id}")
    assert approved_detail.status_code == 200
    approved_score_versions = approved_detail.json()["score_versions"]
    approved_default = next(
        version for version in approved_score_versions if version["is_default"]
    )
    assert approved_default["version_type"] == "approved"
    assert approved_detail.json()["status"] == "approved"
