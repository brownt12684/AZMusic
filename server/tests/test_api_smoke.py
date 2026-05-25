import asyncio
import hashlib
import json
from io import BytesIO
from xml.etree import ElementTree

import pytest
import server.database as database_module
import server.main as main_module
import server.routers.pieces as pieces_router_module
from fastapi.testclient import TestClient
from pypdf import PdfWriter
from server.config import settings
from server.jobs.dispatcher import JobDispatcher
from server.main import app
from server.models.orm import Base
from server.services import book_preprocessing as book_preprocessing_module
from server.services import processing_engines as processing_engines_module
from server.services import score_processing as score_processing_module
from server.services.ocr_metadata import OcrMetadataResult, infer_metadata_from_text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine


async def _create_schema(engine) -> None:
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)


def _valid_pdf_bytes(page_count: int = 1) -> bytes:
    writer = PdfWriter()
    for _ in range(page_count):
        writer.add_blank_page(width=612, height=792)
    output = BytesIO()
    writer.write(output)
    return output.getvalue()


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
    monkeypatch.setattr(database_module, "async_session", session_factory)
    monkeypatch.setattr(main_module, "engine", test_engine)
    monkeypatch.setattr(settings, "storage_path", test_storage_path)
    monkeypatch.setattr(settings, "job_dispatcher_enabled", False)
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
    assert client.get("/api/v1/processing/settings").status_code == 200
    assert client.get("/api/v1/pairing/code").status_code == 200
    assert client.get("/setup").status_code == 200


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
    assert (storage_path / "media" / piece_id / f"{detail['media_assets'][0]['id']}.jpg").exists()


def test_piece_detail_exposes_download_metadata(api_client) -> None:
    client, _ = api_client
    raw_pdf_bytes = b"%PDF-1.4\n%AZMusic metadata test\n"

    import_response = client.post(
        "/api/v1/pieces/import",
        data={
            "title": "Metadata Sonata",
            "composer": "Family Composer",
        },
        files={
            "file": (
                "metadata_sonata.pdf",
                raw_pdf_bytes,
                "application/pdf",
            )
        },
    )
    assert import_response.status_code == 200

    piece_id = import_response.json()["id"]
    detail_response = client.get(f"/api/v1/pieces/{piece_id}")
    assert detail_response.status_code == 200
    score_versions = detail_response.json()["score_versions"]

    raw_version = next(version for version in score_versions if version["version_type"] == "raw")
    assert raw_version["content_type"] == "application/pdf"
    assert raw_version["file_size_bytes"] == len(raw_pdf_bytes)
    assert raw_version["content_sha256"] == hashlib.sha256(raw_pdf_bytes).hexdigest()

    canonical_version = next(
        version for version in score_versions if version["file_path"].endswith(".musicxml")
    )
    assert canonical_version["content_type"] == "application/vnd.recordare.musicxml+xml"
    assert canonical_version["file_size_bytes"] > 0
    assert len(canonical_version["content_sha256"]) == 64


def test_pdf_import_uses_filename_metadata_suggestion_when_fields_missing(api_client) -> None:
    client, _ = api_client

    import_response = client.post(
        "/api/v1/pieces/import",
        data={},
        files={
            "file": (
                "Bach - Minuet 1.pdf",
                b"%PDF-1.4\n%AZMusic filename metadata test\n",
                "application/pdf",
            )
        },
    )
    assert import_response.status_code == 200
    piece = import_response.json()
    piece_id = piece["id"]
    assert piece["title"] == "Minuet 1"
    assert piece["composer"] == "Bach"
    assert piece["catalog_metadata"]["title"] == "Minuet 1"
    assert piece["catalog_metadata"]["composer"] == "Bach"
    filename_suggestion = next(
        suggestion
        for suggestion in piece["catalog_suggestions"]
        if suggestion["source"] == "filename_heuristic"
    )
    assert filename_suggestion["confidence"] == 0.35
    assert filename_suggestion["fields"]["title"] == "Minuet 1"
    assert filename_suggestion["fields"]["composer"] == "Bach"
    assert filename_suggestion["fields"]["source_file_name"] == "Bach - Minuet 1.pdf"

    review_item = next(
        item for item in client.get("/api/v1/review/").json() if item["piece_id"] == piece_id
    )
    assert review_item["candidate_data"]["piece_title"] == "Minuet 1"
    assert review_item["candidate_data"]["catalog_metadata"]["title"] == "Minuet 1"
    assert review_item["candidate_data"]["catalog_metadata"]["composer"] == "Bach"


def test_ocr_metadata_parser_extracts_relevant_score_fields() -> None:
    metadata = infer_metadata_from_text(
        """
        Minuet in G
        Johann Sebastian Bach
        For Violin and Piano
        Notebook for Anna Magdalena Bach
        BWV Anh. 114
        Allegro
        """
    )

    assert metadata["title"] == "Minuet in G"
    assert metadata["composer"] == "Johann Sebastian Bach"
    assert metadata["primary_instrument"] == "Violin"
    assert metadata["book_or_collection"] == "Notebook for Anna Magdalena Bach"
    assert metadata["catalog_number"] == "BWV Anh. 114"
    assert metadata["tempo"] == "Allegro"


def test_image_import_uses_ocr_metadata_for_parent_review(api_client, monkeypatch) -> None:
    client, storage_path = api_client

    def fake_extract(self, *, file_name: str, file_bytes: bytes) -> OcrMetadataResult:
        return OcrMetadataResult(
            metadata={
                "title": "Morning Study",
                "composer": "Family Composer",
                "primary_instrument": "Piano",
                "book_or_collection": "Lesson Book 2",
                "ocr_text_excerpt": "Morning Study Family Composer Piano",
                "ocr_engine": "test_ocr",
                "ocr_confidence": 0.78,
            },
            catalog_suggestions=[
                {
                    "source": "ocr_text",
                    "confidence": 0.78,
                    "fields": {
                        "title": "Morning Study",
                        "composer": "Family Composer",
                        "primary_instrument": "Piano",
                        "book_or_collection": "Lesson Book 2",
                    },
                }
            ],
            confidence=0.78,
            engine_name="test_ocr",
        )

    monkeypatch.setattr(score_processing_module.OcrMetadataExtractor, "extract", fake_extract)

    import_response = client.post(
        "/api/v1/pieces/import",
        data={},
        files={"file": ("scan.jpg", b"fake image bytes", "image/jpeg")},
    )

    assert import_response.status_code == 200
    piece = import_response.json()
    piece_id = piece["id"]
    assert piece["title"] == "Morning Study"
    assert piece["composer"] == "Family Composer"
    assert piece["primary_instrument"] == "Piano"
    assert piece["book_or_collection"] == "Lesson Book 2"
    assert piece["processed_metadata"]["ocr_engine"] == "test_ocr"
    assert piece["catalog_suggestions"][0]["source"] == "filename_heuristic"
    assert piece["catalog_suggestions"][1]["source"] == "ocr_text"
    assert (storage_path / "pieces" / piece_id / "raw_source.jpg").exists()

    review_item = next(
        item for item in client.get("/api/v1/review/").json() if item["piece_id"] == piece_id
    )
    assert review_item["candidate_data"]["piece_title"] == "Morning Study"
    assert review_item["candidate_data"]["raw_file_url"].endswith("/file")
    assert "rendered_file_url" not in review_item["candidate_data"]

    approve_response = client.post(
        f"/api/v1/review/{review_item['id']}",
        json={"action": "approve"},
    )
    assert approve_response.status_code == 200
    detail = client.get(f"/api/v1/pieces/{piece_id}").json()
    approved_raw = next(version for version in detail["score_versions"] if version["is_default"])
    assert approved_raw["version_type"] == "approved"
    assert approved_raw["content_type"] == "image/jpeg"


def test_book_import_uses_ocr_metadata_for_book_record(api_client, monkeypatch) -> None:
    client, _ = api_client

    def fake_extract(self, *, file_name: str, file_bytes: bytes) -> OcrMetadataResult:
        return OcrMetadataResult(
            metadata={
                "title": "Suzuki Violin School Volume 1",
                "composer": "Shinichi Suzuki",
                "primary_instrument": "Violin",
                "ocr_text_excerpt": "Suzuki Violin School Volume 1 Shinichi Suzuki",
            },
            catalog_suggestions=[
                {
                    "source": "ocr_text",
                    "confidence": 0.78,
                    "fields": {
                        "title": "Suzuki Violin School Volume 1",
                        "composer": "Shinichi Suzuki",
                        "primary_instrument": "Violin",
                    },
                }
            ],
            confidence=0.78,
            engine_name="test_ocr",
        )

    monkeypatch.setattr(score_processing_module.OcrMetadataExtractor, "extract", fake_extract)

    import_response = client.post(
        "/api/v1/pieces/import",
        data={"catalog_mode": "book"},
        files={
            "file": (
                "scan_book.pdf",
                _valid_pdf_bytes(page_count=2),
                "application/pdf",
            )
        },
    )

    assert import_response.status_code == 200
    book = import_response.json()
    assert book["title"] == "Suzuki Violin School Volume 1"
    assert book["composer"] == "Shinichi Suzuki"
    assert book["piece_kind"] == "book"
    assert book["processed_metadata"]["title"] == "Suzuki Violin School Volume 1"
    assert book["catalog_suggestions"][0]["source"] == "ocr_text"


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


def test_sync_state_defaults_to_offline_ready(api_client) -> None:
    client, _ = api_client

    response = client.get("/api/v1/sync/offline-surface")
    assert response.status_code == 200
    assert response.json() == {
        "client_id": "offline-surface",
        "last_sync": None,
        "pending_uploads": 0,
        "pending_downloads": 0,
        "status": "offline-ready",
        "has_pending_work": False,
        "retry_required": False,
        "last_attempt_at": None,
        "last_success_at": None,
        "last_failure_at": None,
        "last_error": None,
    }


def test_sync_state_patch_tracks_retry_metadata(api_client) -> None:
    client, _ = api_client

    failed_sync = client.patch(
        "/api/v1/sync/family-surface",
        json={
            "status": "sync-failed-usable",
            "pending_uploads": 1,
            "last_error": "LAN server unreachable",
            "retry_required": True,
        },
    )
    assert failed_sync.status_code == 200
    failed_state = failed_sync.json()
    assert failed_state["status"] == "sync-failed-usable"
    assert failed_state["has_pending_work"] is True
    assert failed_state["retry_required"] is True
    assert failed_state["last_error"] == "LAN server unreachable"
    assert failed_state["last_attempt_at"] is not None
    assert failed_state["last_failure_at"] is not None

    recovered_sync = client.patch(
        "/api/v1/sync/family-surface",
        json={
            "status": "synced",
            "pending_uploads": 0,
            "pending_downloads": 0,
            "retry_required": False,
            "last_error": None,
        },
    )
    assert recovered_sync.status_code == 200
    recovered_state = recovered_sync.json()
    assert recovered_state["status"] == "synced"
    assert recovered_state["has_pending_work"] is False
    assert recovered_state["retry_required"] is False
    assert recovered_state["last_error"] is None
    assert recovered_state["last_sync"] is not None
    assert recovered_state["last_success_at"] is not None

    persisted_sync = client.get("/api/v1/sync/family-surface")
    assert persisted_sync.status_code == 200
    persisted_state = persisted_sync.json()
    assert persisted_state["status"] == "synced"
    assert persisted_state["retry_required"] is False
    assert persisted_state["last_error"] is None


def test_pdf_import_processing_and_approval_flow(api_client) -> None:
    client, storage_path = api_client

    import_response = client.post(
        "/api/v1/pieces/import",
        data={
            "title": "Canon in D",
            "composer": "Pachelbel",
        },
        files={"file": ("canon_in_d.pdf", b"%PDF-1.4\n%AZMusic test pdf\n", "application/pdf")},
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
    assert review_item["candidate_data"]["engine_name"] == "stub"
    assert review_item["candidate_data"]["renderer_name"] == "raw_pdf_fallback"
    assert review_item["candidate_data"]["warnings"]
    processed_metadata = review_item["candidate_data"]["processed_metadata"]
    assert processed_metadata["title"] == "Canon in D"
    assert processed_metadata["composer"] == "Pachelbel"
    assert "primary_instrument" not in processed_metadata
    assert processed_metadata["key_signature"] == "C major"
    assert processed_metadata["time_signature"] == "4/4"
    assert processed_metadata["tempo"] == "96"
    assert processed_metadata["measure_count"] == 1

    detail_with_metadata = client.get(f"/api/v1/pieces/{piece_id}").json()
    assert detail_with_metadata["key_signature"] == "C major"
    assert detail_with_metadata["tempo"] == "96"
    assert detail_with_metadata["processed_metadata"]["title"] == "Canon in D"

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
    assert job["result_data"]["engine_name"] == "stub"

    approve_response = client.post(
        f"/api/v1/review/{review_item['id']}",
        json={
            "action": "approve",
            "correction": {
                "title": "Canon in D",
                "composer": "Johann Pachelbel",
                "book_or_collection": "Family Recital Book",
            },
        },
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

    metadata_update = client.patch(
        f"/api/v1/pieces/{piece_id}",
        json={
            "title": "Canon in D Major",
            "composer": None,
            "primary_instrument": "Violin",
            "book_or_collection": "Family Recital Book",
            "key_signature": "D major",
            "tempo": "84",
            "notes": "Use this corrected catalog record on student devices.",
            "catalog_metadata": {"aliases": ["Pachelbel Canon"]},
        },
    )
    assert metadata_update.status_code == 200
    updated_piece = metadata_update.json()
    assert updated_piece["title"] == "Canon in D Major"
    assert updated_piece["composer"] is None
    assert updated_piece["notes"] == "Use this corrected catalog record on student devices."
    assert updated_piece["catalog_metadata"]["aliases"] == ["Pachelbel Canon"]

    assigned_after_update = client.get("/api/v1/pieces/assigned/student-alyse")
    assert assigned_after_update.status_code == 200
    assigned_updated = next(item for item in assigned_after_update.json() if item["id"] == piece_id)
    assert assigned_updated["title"] == "Canon in D Major"
    assert assigned_updated["composer"] is None
    assert assigned_updated["notes"] == "Use this corrected catalog record on student devices."

    approved_detail = client.get(f"/api/v1/pieces/{piece_id}")
    assert approved_detail.status_code == 200
    approved_payload = approved_detail.json()
    assert approved_payload["title"] == "Canon in D Major"
    assert approved_payload["composer"] is None
    assert approved_payload["book_or_collection"] == "Family Recital Book"
    assert approved_payload["catalog_metadata"]["key_signature"] == "D major"
    approved_score_versions = approved_payload["score_versions"]
    approved_default = next(version for version in approved_score_versions if version["is_default"])
    assert approved_default["version_type"] == "approved"
    assert approved_payload["status"] == "approved"


def test_parent_can_open_and_rerender_musescore_candidate(api_client, monkeypatch) -> None:
    client, storage_path = api_client

    import_response = client.post(
        "/api/v1/pieces/import",
        data={"title": "Editable Etude", "composer": "Parent Composer"},
        files={
            "file": (
                "editable_etude.pdf",
                b"%PDF-1.4\n%AZMusic MuseScore edit test\n",
                "application/pdf",
            )
        },
    )
    assert import_response.status_code == 200
    piece_id = import_response.json()["id"]

    detail = client.get(f"/api/v1/pieces/{piece_id}").json()
    canonical_version = next(
        version
        for version in detail["score_versions"]
        if version["file_path"].endswith(".musicxml")
    )
    rendered_version = next(
        version
        for version in detail["score_versions"]
        if version["file_path"].endswith("_review.pdf")
    )
    review_item = next(
        item for item in client.get("/api/v1/review/").json() if item["piece_id"] == piece_id
    )

    fake_musescore = storage_path / "fake_musescore.exe"
    fake_musescore.write_text("fake musescore executable", encoding="utf-8")
    settings_response = client.patch(
        "/api/v1/processing/settings",
        json={"musescore_cli_path": str(fake_musescore)},
    )
    assert settings_response.status_code == 200

    launches = []

    class FakeExecutableStatus:
        discovered_path = str(fake_musescore)

    class FakeProcess:
        pass

    def fake_executable_status(**_kwargs):
        return FakeExecutableStatus()

    def fake_popen(command, cwd=None):
        launches.append((command, cwd))
        return FakeProcess()

    monkeypatch.setattr(pieces_router_module, "executable_status", fake_executable_status)
    monkeypatch.setattr(pieces_router_module.subprocess, "Popen", fake_popen)

    open_response = client.post(
        f"/api/v1/pieces/{piece_id}/score_versions/{canonical_version['id']}/open-musescore"
    )
    assert open_response.status_code == 200
    assert open_response.json()["status"] == "opened"
    assert launches == [
        (
            [str(fake_musescore), canonical_version["file_path"]],
            str(storage_path / "pieces" / piece_id),
        )
    ]

    def fake_render(self, *, canonical_path, raw_pdf_path, output_pdf_path, processing_settings):
        assert canonical_path.name == "candidate.musicxml"
        assert raw_pdf_path.name == "raw_source.pdf"
        output_pdf_path.write_bytes(b"%PDF-1.4\n%edited by parent\n")
        return processing_engines_module.RenderResult(
            file_path=output_pdf_path,
            renderer_name="musescore",
            renderer_version="test-renderer",
            provenance="musescore_render",
            warnings=["render refreshed after parent MuseScore edit"],
        )

    monkeypatch.setattr(pieces_router_module.MuseScoreRenderEngine, "render", fake_render)

    rerender_response = client.post(
        f"/api/v1/pieces/{piece_id}/score_versions/{canonical_version['id']}/rerender",
        json={"rendered_score_version_id": rendered_version["id"]},
    )
    assert rerender_response.status_code == 200
    assert rerender_response.json()["status"] == "rendered"

    refreshed_item = client.get(f"/api/v1/review/{review_item['id']}").json()
    candidate_data = refreshed_item["candidate_data"]
    assert candidate_data["renderer_name"] == "musescore"
    assert candidate_data["renderer_version"] == "test-renderer"
    assert candidate_data["manual_musescore_rendered_at"]
    assert "render refreshed after parent MuseScore edit" in candidate_data["warnings"]
    assert (storage_path / "pieces" / piece_id / "candidate_review.pdf").read_bytes() == (
        b"%PDF-1.4\n%edited by parent\n"
    )


def test_parent_can_upload_edited_musicxml_and_refresh_review_pdf(
    api_client,
    monkeypatch,
) -> None:
    client, storage_path = api_client

    import_response = client.post(
        "/api/v1/pieces/import",
        data={"title": "Parent Device Edit", "composer": "Family Composer"},
        files={
            "file": (
                "parent_device_edit.pdf",
                b"%PDF-1.4\n%AZMusic parent-device edit test\n",
                "application/pdf",
            )
        },
    )
    assert import_response.status_code == 200
    piece_id = import_response.json()["id"]
    detail = client.get(f"/api/v1/pieces/{piece_id}").json()
    canonical_version = next(
        version
        for version in detail["score_versions"]
        if version["file_path"].endswith(".musicxml")
    )
    rendered_version = next(
        version
        for version in detail["score_versions"]
        if version["file_path"].endswith("_review.pdf")
    )
    review_item = next(
        item for item in client.get("/api/v1/review/").json() if item["piece_id"] == piece_id
    )
    edited_musicxml = b"""<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0"><movement-title>Parent Corrected</movement-title></score-partwise>
"""

    def fake_render(self, *, canonical_path, raw_pdf_path, output_pdf_path, processing_settings):
        assert canonical_path.read_bytes() == edited_musicxml
        output_pdf_path.write_bytes(b"%PDF-1.4\n%rerendered from parent upload\n")
        return processing_engines_module.RenderResult(
            file_path=output_pdf_path,
            renderer_name="musescore",
            renderer_version="parent-upload-test",
            provenance="musescore_render",
            warnings=["render refreshed from uploaded MusicXML"],
        )

    monkeypatch.setattr(pieces_router_module.MuseScoreRenderEngine, "render", fake_render)

    upload_response = client.post(
        f"/api/v1/pieces/{piece_id}/score_versions/{canonical_version['id']}/edited-candidate",
        data={"rendered_score_version_id": rendered_version["id"]},
        files={
            "file": (
                "edited_candidate.musicxml",
                edited_musicxml,
                "application/vnd.recordare.musicxml+xml",
            )
        },
    )
    assert upload_response.status_code == 200
    payload = upload_response.json()
    assert payload["status"] == "rendered"
    assert payload["uploaded_file_name"] == "edited_candidate.musicxml"
    assert payload["renderer_version"] == "parent-upload-test"
    assert payload["rendered_content_sha256"]

    piece_dir = storage_path / "pieces" / piece_id
    assert (piece_dir / "candidate.musicxml").read_bytes() == edited_musicxml
    assert (piece_dir / "candidate_review.pdf").read_bytes() == (
        b"%PDF-1.4\n%rerendered from parent upload\n"
    )

    refreshed_item = client.get(f"/api/v1/review/{review_item['id']}").json()
    candidate_data = refreshed_item["candidate_data"]
    assert candidate_data["renderer_name"] == "musescore"
    assert candidate_data["renderer_version"] == "parent-upload-test"
    assert "render refreshed from uploaded MusicXML" in candidate_data["warnings"]

    invalid_response = client.post(
        f"/api/v1/pieces/{piece_id}/score_versions/{canonical_version['id']}/edited-candidate",
        data={"rendered_score_version_id": rendered_version["id"]},
        files={"file": ("not_music.txt", b"not musicxml", "text/plain")},
    )
    assert invalid_response.status_code == 400


def test_book_pdf_import_preserves_book_and_creates_child_review_candidates(
    api_client,
) -> None:
    client, storage_path = api_client
    split_hints = [
        {
            "title": "Twinkle Variation A",
            "page_start": 1,
            "page_end": 2,
            "composer": "Shinichi Suzuki",
            "primary_instrument": "Violin",
            "confidence": 0.91,
        },
        {
            "title": "Lightly Row",
            "page_start": 3,
            "page_end": 4,
            "composer": "Folk Song",
            "primary_instrument": "Violin",
            "confidence": 0.86,
            "validation_warnings": ["Title matched from supplied split hint."],
        },
    ]

    import_response = client.post(
        "/api/v1/pieces/import",
        data={
            "title": "Suzuki Book 1",
            "composer": "Shinichi Suzuki",
            "book_or_collection": "Suzuki Violin School Volume 1",
            "catalog_mode": "book",
            "split_hints": json.dumps(split_hints),
        },
        files={
            "file": (
                "suzuki_book_1.pdf",
                _valid_pdf_bytes(page_count=4),
                "application/pdf",
            )
        },
    )
    assert import_response.status_code == 200
    book = import_response.json()
    book_id = book["id"]
    assert book["piece_kind"] == "book"
    assert book["library_status"] == "intake"
    assert book["catalog_metadata"]["book_or_collection"] == ("Suzuki Violin School Volume 1")
    assert (storage_path / "pieces" / book_id / "raw_source.pdf").exists()

    pieces = client.get("/api/v1/pieces/").json()
    children = [piece for piece in pieces if piece["source_book_id"] == book_id]
    assert len(children) == 2
    assert {child["title"] for child in children} == {
        "Twinkle Variation A",
        "Lightly Row",
    }

    twinkle = next(child for child in children if child["title"] == "Twinkle Variation A")
    assert twinkle["piece_kind"] == "piece"
    assert twinkle["source_page_start"] == 1
    assert twinkle["source_page_end"] == 2
    assert twinkle["book_or_collection"] == "Suzuki Violin School Volume 1"
    assert twinkle["split_confidence"] == 0.91
    assert twinkle["catalog_suggestions"][0]["source"] == "book_split_hint"

    review_items = client.get("/api/v1/review/").json()
    child_review_items = [
        item for item in review_items if item["piece_id"] in {child["id"] for child in children}
    ]
    assert len(child_review_items) == 2
    review_item = next(
        item
        for item in child_review_items
        if item["candidate_data"]["piece_title"] == "Lightly Row"
    )
    assert review_item["candidate_data"]["source_book_id"] == book_id
    assert review_item["candidate_data"]["source_page_start"] == 3
    assert review_item["candidate_data"]["source_page_end"] == 4
    assert review_item["candidate_data"]["catalog_metadata"]["book_or_collection"] == (
        "Suzuki Violin School Volume 1"
    )


def test_book_pdf_import_without_split_hints_uses_preprocessing_baseline(
    api_client,
    monkeypatch,
) -> None:
    client, storage_path = api_client

    class FakeBookPreprocessor:
        def __init__(self, processing_settings) -> None:
            self.processing_settings = processing_settings

        def preprocess(self, *, file_name: str, file_bytes: bytes):
            return score_processing_module.BookPreprocessingResult(
                page_count=4,
                page_facts=[
                    score_processing_module.BookPageFact(
                        page_number=1,
                        text="Position Pieces Rick Mooney",
                        text_excerpt="Position Pieces Rick Mooney",
                        classification="cover",
                        title_candidates=[],
                        has_staff_hint=False,
                        dark_pixel_ratio=0.04,
                        horizontal_line_count=3,
                    ),
                    score_processing_module.BookPageFact(
                        page_number=2,
                        text="Fanfare",
                        text_excerpt="Fanfare",
                        classification="music_piece",
                        title_candidates=["Fanfare"],
                        has_staff_hint=True,
                        dark_pixel_ratio=0.08,
                        horizontal_line_count=24,
                    ),
                    score_processing_module.BookPageFact(
                        page_number=3,
                        text="The Elephant's Waltz",
                        text_excerpt="The Elephant's Waltz",
                        classification="music_piece",
                        title_candidates=["The Elephant's Waltz"],
                        has_staff_hint=True,
                        dark_pixel_ratio=0.08,
                        horizontal_line_count=24,
                    ),
                    score_processing_module.BookPageFact(
                        page_number=4,
                        text="Geography Quiz",
                        text_excerpt="Geography Quiz",
                        classification="instructional",
                        title_candidates=[],
                        has_staff_hint=False,
                        dark_pixel_ratio=0.04,
                        horizontal_line_count=3,
                    ),
                ],
                split_proposals=[
                    score_processing_module.BookSplitProposal(
                        title="Fanfare",
                        page_start=2,
                        page_end=2,
                        composer="Rick Mooney",
                        primary_instrument="Cello",
                        confidence=0.88,
                    ),
                    score_processing_module.BookSplitProposal(
                        title="The Elephant's Waltz",
                        page_start=3,
                        page_end=3,
                        composer="Rick Mooney",
                        primary_instrument="Cello",
                        confidence=0.87,
                    ),
                ],
                book_metadata={
                    "title": "Position Pieces for Cello, Book 1",
                    "composer": "Rick Mooney",
                    "primary_instrument": "Cello",
                    "book_or_collection": "Position Pieces for Cello, Book 1",
                },
            )

    monkeypatch.setattr(score_processing_module, "BookPreprocessor", FakeBookPreprocessor)

    import_response = client.post(
        "/api/v1/pieces/import",
        data={"catalog_mode": "book"},
        files={
            "file": (
                "Position Pieces for Cello, Book 1.pdf",
                _valid_pdf_bytes(page_count=4),
                "application/pdf",
            )
        },
    )
    assert import_response.status_code == 200
    book = import_response.json()
    book_id = book["id"]
    assert book["piece_kind"] == "book"
    assert book["title"] == "Position Pieces for Cello, Book 1"
    assert book["composer"] == "Rick Mooney"
    assert book["processed_metadata"]["book_preprocessing"]["page_count"] == 4
    assert (storage_path / "pieces" / book_id / "raw_source.pdf").exists()

    pieces = client.get("/api/v1/pieces/").json()
    children = [piece for piece in pieces if piece["source_book_id"] == book_id]
    assert {child["title"] for child in children} == {
        "Fanfare",
        "The Elephant's Waltz",
    }
    assert all(child["library_status"] == "review" for child in children)

    jobs = client.get("/api/v1/jobs/").json()
    assert any(job["job_type"] == "book_import" for job in jobs)
    assert not any(
        job["job_type"] == "score_processing" and job["piece_id"] == book_id for job in jobs
    )

    review_items = client.get("/api/v1/review/").json()
    assert len(review_items) == 2
    fanfare_review = next(
        item for item in review_items if item["candidate_data"]["piece_title"] == "Fanfare"
    )
    assert fanfare_review["candidate_data"]["provenance"] == ("book_preprocessing_tesseract")
    assert fanfare_review["candidate_data"]["source_page_start"] == 2
    assert fanfare_review["candidate_data"]["source_page_end"] == 2

    approve_response = client.post(
        f"/api/v1/review/{fanfare_review['id']}",
        json={"action": "approve"},
    )
    assert approve_response.status_code == 200
    fanfare_piece = client.get(f"/api/v1/pieces/{fanfare_review['piece_id']}").json()
    assert fanfare_piece["status"] == "processing"
    jobs_after_approval = client.get("/api/v1/jobs/").json()
    queued_jobs = [
        job
        for job in jobs_after_approval
        if job["piece_id"] == fanfare_review["piece_id"] and job["job_type"] == "score_processing"
    ]
    assert queued_jobs[0]["status"] == "queued"


def test_likely_book_pdf_import_auto_uses_preprocessing(
    api_client,
    monkeypatch,
) -> None:
    client, _ = api_client

    class FakeBookPreprocessor:
        def __init__(self, processing_settings) -> None:
            self.processing_settings = processing_settings

        def preprocess(self, *, file_name: str, file_bytes: bytes):
            return score_processing_module.BookPreprocessingResult(
                page_count=9,
                page_facts=[],
                split_proposals=[
                    score_processing_module.BookSplitProposal(
                        title="Fanfare",
                        page_start=2,
                        page_end=2,
                        composer="Rick Mooney",
                        primary_instrument="Cello",
                        confidence=0.88,
                    ),
                ],
                book_metadata={
                    "title": "Position Pieces for Cello, Book 1",
                    "composer": "Rick Mooney",
                    "primary_instrument": "Cello",
                    "book_or_collection": "Position Pieces for Cello, Book 1",
                },
            )

    monkeypatch.setattr(score_processing_module, "BookPreprocessor", FakeBookPreprocessor)

    import_response = client.post(
        "/api/v1/pieces/import",
        files={
            "file": (
                "Position Pieces for Cello, Book 1.pdf",
                _valid_pdf_bytes(page_count=9),
                "application/pdf",
            )
        },
    )

    assert import_response.status_code == 200
    book = import_response.json()
    assert book["piece_kind"] == "book"
    assert book["primary_instrument"] == "Cello"
    assert book["processed_metadata"]["book_preprocessing"]["page_count"] == 9

    jobs = client.get("/api/v1/jobs/").json()
    assert any(job["job_type"] == "book_import" for job in jobs)
    assert not any(
        job["job_type"] == "score_processing" and job["piece_id"] == book["id"] for job in jobs
    )


def test_book_preprocessing_keeps_multiple_short_pieces_on_one_page() -> None:
    page_facts = [
        book_preprocessing_module.BookPageFact(
            page_number=39,
            text="The Troubadour * see the note on The Invisible Target Hoedown",
            text_excerpt="The Troubadour * see the note on The Invisible Target Hoedown",
            classification="music_piece",
            title_candidates=["The Troubadour", "Hoedown."],
            has_staff_hint=True,
            dark_pixel_ratio=0.06,
            horizontal_line_count=44,
        ),
        book_preprocessing_module.BookPageFact(
            page_number=40,
            text="A Waltz",
            text_excerpt="A Waltz",
            classification="music_piece",
            title_candidates=["A Waltz"],
            has_staff_hint=True,
            dark_pixel_ratio=0.04,
            horizontal_line_count=34,
        ),
    ]

    proposals = book_preprocessing_module._propose_splits(
        page_facts,
        {
            "composer": "Rick Mooney",
            "primary_instrument": "Cello",
        },
    )

    shared_page = proposals[0]
    assert shared_page.title == "The Troubadour / Hoedown"
    assert shared_page.page_start == 39
    assert shared_page.page_end == 39
    assert shared_page.contained_piece_titles == ["The Troubadour", "Hoedown"]
    assert shared_page.multi_piece_page is True
    assert shared_page.primary_instrument == "Cello"
    assert any("kept together" in warning for warning in shared_page.validation_warnings)
    assert proposals[1].title == "A Waltz"


def test_musicxml_generation_uses_title_and_cello_instrument(tmp_path) -> None:
    raw_pdf_path = tmp_path / "raw.pdf"
    raw_pdf_path.write_bytes(_valid_pdf_bytes(page_count=1))
    output_path = tmp_path / "candidate.musicxml"

    result = processing_engines_module.MusicXmlEngine().generate(
        raw_pdf_path=raw_pdf_path,
        output_path=output_path,
        title="The Troubadour / Hoedown",
        composer="Rick Mooney",
        primary_instrument="Cello",
        contained_piece_titles=["The Troubadour", "Hoedown"],
        multi_piece_page=True,
        processing_settings={"allow_stub_musicxml": True},
    )

    musicxml = result.file_path.read_text(encoding="utf-8")
    assert "<work-title>The Troubadour / Hoedown</work-title>" in musicxml
    assert "<movement-title>The Troubadour</movement-title>" in musicxml
    assert "<movement-title>The Troubadour / Hoedown</movement-title>" not in musicxml
    assert '<words font-weight="bold" font-size="16">Hoedown</words>' in musicxml
    assert '<creator type="composer">Rick Mooney</creator>' in musicxml
    assert "Voice" not in musicxml
    assert 'part-name print-object="no"' in musicxml
    assert "<instrument-name>Cello</instrument-name>" in musicxml
    assert result.metadata["primary_instrument"] == "Cello"
    assert result.metadata["title"] == "The Troubadour / Hoedown"
    assert result.metadata["movement_title"] == "The Troubadour"


def test_musicxml_normalization_overrides_voice_with_book_instrument(tmp_path) -> None:
    raw_path = tmp_path / "audiveris.musicxml"
    output_path = tmp_path / "candidate.musicxml"
    raw_path.write_text(
        """<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1">
      <part-name>Voice</part-name>
      <score-instrument id="P1-I1"><instrument-name>Voice</instrument-name></score-instrument>
    </score-part>
    <score-part id="P2">
      <part-name>Voice</part-name>
      <part-abbreviation>Voice</part-abbreviation>
    </score-part>
  </part-list>
  <part id="P1"><measure number="1"/></part>
  <part id="P2"><measure number="1"/></part>
</score-partwise>
""",
        encoding="utf-8",
    )
    result = processing_engines_module.MusicXmlResult(
        file_path=raw_path,
        engine_name="audiveris",
        engine_version="test",
        provenance="audiveris_omr",
        confidence=0.82,
        metadata={"primary_instrument": "Voice"},
    )

    normalized = processing_engines_module._normalize_result_metadata(
        result,
        output_path=output_path,
        title="Fanfare",
        composer="Rick Mooney",
        primary_instrument="Cello",
    )

    assert normalized.metadata["primary_instrument"] == "Cello"
    assert "omr_primary_instrument" not in normalized.metadata
    assert any("generic OMR part label" in warning for warning in normalized.warnings)
    assert all("Voice" not in warning for warning in normalized.warnings)
    normalized_xml = normalized.file_path.read_text(encoding="utf-8")
    assert "Voice" not in normalized_xml
    root = ElementTree.parse(normalized.file_path).getroot()
    score_part = processing_engines_module._iter_named(root, "score-part")[0]
    part_name = processing_engines_module._first_child(score_part, "part-name")
    assert part_name is not None
    assert part_name.attrib["print-object"] == "no"
    assert part_name.text == " "
    for part in processing_engines_module._iter_named(root, "score-part"):
        part_name = processing_engines_module._first_child(part, "part-name")
        assert part_name is not None
        assert part_name.attrib["print-object"] == "no"
        assert part_name.text == " "
    assert "<instrument-name>Cello</instrument-name>" in normalized_xml


def test_raw_book_can_be_pushed_while_children_are_processing(api_client) -> None:
    client, _ = api_client
    split_hints = [
        {
            "title": "Raw Book Child",
            "page_start": 1,
            "page_end": 1,
            "composer": "Debug Composer",
            "primary_instrument": "Cello",
            "confidence": 0.91,
        }
    ]
    import_response = client.post(
        "/api/v1/pieces/import",
        data={
            "title": "Raw Book",
            "composer": "Debug Composer",
            "catalog_mode": "book",
            "split_hints": json.dumps(split_hints),
        },
        files={
            "file": (
                "raw_book.pdf",
                _valid_pdf_bytes(page_count=1),
                "application/pdf",
            )
        },
    )
    assert import_response.status_code == 200
    book = import_response.json()
    assert book["status"] == "imported"
    assert book["piece_kind"] == "book"

    push_response = client.post(
        f"/api/v1/pieces/{book['id']}/push",
        json={"profile_ids": ["student-cello"]},
    )
    assert push_response.status_code == 200
    pushed_book = push_response.json()
    assert "student-cello" in pushed_book["visible_to_profile_ids"]

    assigned = client.get("/api/v1/pieces/assigned/student-cello").json()
    assigned_book = next(piece for piece in assigned if piece["id"] == book["id"])
    assert assigned_book["title"] == "Raw Book"
    assert assigned_book["library_status"] == "intake"

    child = next(
        piece
        for piece in client.get("/api/v1/pieces/").json()
        if piece["source_book_id"] == book["id"]
    )
    child_push = client.post(
        f"/api/v1/pieces/{child['id']}/push",
        json={"profile_ids": ["student-cello"]},
    )
    assert child_push.status_code == 409


def test_async_dispatcher_processes_approved_book_split(api_client) -> None:
    client, _ = api_client
    split_hints = [
        {
            "title": "Async Fanfare",
            "page_start": 1,
            "page_end": 1,
            "composer": "Debug Composer",
            "confidence": 0.91,
        }
    ]
    import_response = client.post(
        "/api/v1/pieces/import",
        data={
            "title": "Async Book",
            "composer": "Debug Composer",
            "catalog_mode": "book",
            "split_hints": json.dumps(split_hints),
        },
        files={
            "file": (
                "async_book.pdf",
                _valid_pdf_bytes(page_count=1),
                "application/pdf",
            )
        },
    )
    assert import_response.status_code == 200
    book_id = import_response.json()["id"]
    child = next(
        piece
        for piece in client.get("/api/v1/pieces/").json()
        if piece["source_book_id"] == book_id
    )
    split_review = next(
        item for item in client.get("/api/v1/review/").json() if item["piece_id"] == child["id"]
    )

    approve_response = client.post(
        f"/api/v1/review/{split_review['id']}",
        json={"action": "approve"},
    )
    assert approve_response.status_code == 200

    dispatcher = JobDispatcher(poll_interval_seconds=0, stale_after_seconds=1, max_retries=0)
    assert asyncio.run(dispatcher.run_once()) is True

    jobs = client.get("/api/v1/jobs/").json()
    processing_job = next(
        job
        for job in jobs
        if job["piece_id"] == child["id"] and job["job_type"] == "score_processing"
    )
    assert processing_job["status"] == "succeeded"
    assert processing_job["progress"] == 100.0
    assert processing_job["result_data"]["processing_stage"] == "candidate_review_needed"
    assert processing_job["result_data"]["candidate_review_item_id"]

    detail = client.get(f"/api/v1/pieces/{child['id']}").json()
    assert detail["status"] == "review_pending"
    assert len(detail["score_versions"]) == 3

    pending_reviews = client.get("/api/v1/review/").json()
    candidate_review = next(
        item
        for item in pending_reviews
        if item["piece_id"] == child["id"]
        and item["candidate_data"].get("processing_stage") == "candidate_review_needed"
    )
    assert candidate_review["candidate_data"]["rendered_file_url"].endswith("/file")
    assert candidate_review["candidate_data"]["canonical_file_url"].endswith("/file")

    summary = client.get("/api/v1/jobs/summary").json()
    assert summary["queued_count"] == 0
    assert summary["running_count"] == 0
    assert summary["succeeded_count"] >= 1


def test_async_dispatcher_retries_then_fails_visibly(api_client) -> None:
    client, storage_path = api_client
    split_hints = [
        {
            "title": "Failing Fanfare",
            "page_start": 1,
            "page_end": 1,
            "composer": "Debug Composer",
            "confidence": 0.91,
        }
    ]
    import_response = client.post(
        "/api/v1/pieces/import",
        data={
            "title": "Failing Book",
            "composer": "Debug Composer",
            "catalog_mode": "book",
            "split_hints": json.dumps(split_hints),
        },
        files={
            "file": (
                "failing_book.pdf",
                _valid_pdf_bytes(page_count=1),
                "application/pdf",
            )
        },
    )
    assert import_response.status_code == 200
    book_id = import_response.json()["id"]
    child = next(
        piece
        for piece in client.get("/api/v1/pieces/").json()
        if piece["source_book_id"] == book_id
    )
    split_review = next(
        item for item in client.get("/api/v1/review/").json() if item["piece_id"] == child["id"]
    )
    approve_response = client.post(
        f"/api/v1/review/{split_review['id']}",
        json={"action": "approve"},
    )
    assert approve_response.status_code == 200
    settings_response = client.patch(
        "/api/v1/processing/settings",
        json={
            "allow_stub_musicxml": False,
            "audiveris_cli_path": str(storage_path / "missing-audiveris.exe"),
        },
    )
    assert settings_response.status_code == 200

    dispatcher = JobDispatcher(poll_interval_seconds=0, stale_after_seconds=1, max_retries=2)
    assert asyncio.run(dispatcher.run_once()) is True
    retry_job = next(
        job
        for job in client.get("/api/v1/jobs/").json()
        if job["piece_id"] == child["id"] and job["job_type"] == "score_processing"
    )
    assert retry_job["status"] == "queued"
    assert retry_job["result_data"]["retry_count"] == 1

    assert asyncio.run(dispatcher.run_once()) is True
    assert asyncio.run(dispatcher.run_once()) is True
    failed_job = next(
        job
        for job in client.get("/api/v1/jobs/").json()
        if job["piece_id"] == child["id"] and job["job_type"] == "score_processing"
    )
    assert failed_job["status"] == "failed"
    assert failed_job["progress"] == 100.0
    assert "Audiveris" in failed_job["error_message"]

    failed_piece = client.get(f"/api/v1/pieces/{child['id']}").json()
    assert failed_piece["status"] == "imported"
    summary = client.get("/api/v1/jobs/summary").json()
    assert summary["failed_count"] == 1
    assert summary["last_failed_job"]["id"] == failed_job["id"]

    capabilities = client.get("/api/v1/processing/capabilities").json()
    assert capabilities["job_summary"]["failed_count"] == 1


def test_async_dispatcher_requeues_stale_running_jobs(api_client) -> None:
    client, _ = api_client
    job_response = client.post(
        "/api/v1/jobs/trigger",
        json={"job_type": "score_processing"},
    )
    assert job_response.status_code == 200
    job_id = job_response.json()["id"]
    update_response = client.patch(
        f"/api/v1/jobs/{job_id}",
        json={"status": "running", "progress": 50.0},
    )
    assert update_response.status_code == 200

    dispatcher = JobDispatcher(poll_interval_seconds=0, stale_after_seconds=-1)
    assert asyncio.run(dispatcher.requeue_stale_running_jobs()) == 1

    requeued_job = client.get(f"/api/v1/jobs/{job_id}").json()
    assert requeued_job["status"] == "queued"
    assert requeued_job["progress"] == 0.0
    assert requeued_job["result_data"]["requeued_after_stale_running"] is True


def test_review_reprocess_records_unavailable_local_llm(api_client) -> None:
    client, _ = api_client

    import_response = client.post(
        "/api/v1/pieces/import",
        data={"title": "Metadata Needs Review"},
        files={
            "file": (
                "metadata_needs_review.pdf",
                b"%PDF-1.4\n%AZMusic LLM reprocess test\n",
                "application/pdf",
            )
        },
    )
    assert import_response.status_code == 200
    piece_id = import_response.json()["id"]
    review_item = next(
        item for item in client.get("/api/v1/review/").json() if item["piece_id"] == piece_id
    )

    reprocess_response = client.post(
        f"/api/v1/review/{review_item['id']}/reprocess",
        json={
            "reprocess_type": "metadata",
            "parent_notes": "Validate the title and composer.",
        },
    )
    assert reprocess_response.status_code == 200
    job = reprocess_response.json()
    assert job["status"] == "failed"
    assert "Local LLM provider is not configured" in job["error_message"]
    assert job["result_data"]["local_llm_available"] is False

    refreshed_item = client.get(f"/api/v1/review/{review_item['id']}").json()
    warnings = refreshed_item["candidate_data"]["validation_warnings"]
    assert any("Local LLM provider is not configured" in warning for warning in warnings)
    assert refreshed_item["candidate_data"]["reprocess_history"][0]["status"] == "failed"

    settings_after_failure = client.get("/api/v1/processing/settings").json()
    assert (
        "Local LLM provider is not configured"
        in settings_after_failure["last_llm_processing_error"]
    )


def test_score_reprocess_is_wired_as_coming_soon(api_client) -> None:
    client, _ = api_client

    import_response = client.post(
        "/api/v1/pieces/import",
        data={"title": "AI Score Review Placeholder"},
        files={
            "file": (
                "ai_score_review_placeholder.pdf",
                b"%PDF-1.4\n%AZMusic score review coming soon\n",
                "application/pdf",
            )
        },
    )
    assert import_response.status_code == 200
    piece_id = import_response.json()["id"]
    review_item = next(
        item for item in client.get("/api/v1/review/").json() if item["piece_id"] == piece_id
    )

    reprocess_response = client.post(
        f"/api/v1/review/{review_item['id']}/reprocess",
        json={
            "reprocess_type": "score",
            "parent_notes": "Compare the MusicXML to the original PDF.",
        },
    )
    assert reprocess_response.status_code == 200
    job = reprocess_response.json()
    assert job["status"] == "failed"
    assert job["result_data"]["coming_soon"] is True
    assert "AI score review is coming soon" in job["error_message"]

    refreshed_item = client.get(f"/api/v1/review/{review_item['id']}").json()
    warnings = refreshed_item["candidate_data"]["validation_warnings"]
    assert any("AI score review is coming soon" in warning for warning in warnings)
    assert refreshed_item["candidate_data"]["reprocess_history"][0]["reprocess_type"] == "score"


def test_rejected_review_archives_piece_and_leaves_pending_queue(api_client) -> None:
    client, _ = api_client

    import_response = client.post(
        "/api/v1/pieces/import",
        data={"title": "Rejected Candidate Study"},
        files={
            "file": (
                "rejected_candidate_study.pdf",
                b"%PDF-1.4\n%AZMusic reject test pdf\n",
                "application/pdf",
            )
        },
    )
    assert import_response.status_code == 200
    piece_id = import_response.json()["id"]

    review_items = client.get("/api/v1/review/").json()
    review_item = next(item for item in review_items if item["piece_id"] == piece_id)

    reject_response = client.post(
        f"/api/v1/review/{review_item['id']}",
        json={"action": "reject"},
    )
    assert reject_response.status_code == 200
    assert reject_response.json()["status"] == "rejected"

    pending_queue = client.get("/api/v1/review/").json()
    assert all(item["id"] != review_item["id"] for item in pending_queue)

    resolved_queue = client.get("/api/v1/review/?include_resolved=true").json()
    resolved_item = next(item for item in resolved_queue if item["id"] == review_item["id"])
    assert resolved_item["status"] == "rejected"

    piece_detail = client.get(f"/api/v1/pieces/{piece_id}").json()
    assert piece_detail["status"] == "archived"
    assert piece_detail["library_status"] == "archived"

    push_response = client.post(
        f"/api/v1/pieces/{piece_id}/push",
        json={"profile_ids": ["student-alyse"]},
    )
    assert push_response.status_code == 409


def test_processing_settings_and_device_worker_registration(api_client) -> None:
    client, storage_path = api_client

    settings_response = client.get("/api/v1/processing/settings")
    assert settings_response.status_code == 200
    settings_payload = settings_response.json()
    assert settings_payload["processing_mode"] == "server_only"
    assert settings_payload["allow_stub_musicxml"] is True
    assert settings_payload["local_llm_provider"] is None
    assert settings_payload["cloud_enabled"] is False
    assert settings_payload["cloud_api_key_configured"] is False

    missing_audiveris = storage_path / "missing-audiveris.exe"
    validation_response = client.post(
        "/api/v1/processing/settings/validate",
        json={"audiveris_cli_path": str(missing_audiveris)},
    )
    assert validation_response.status_code == 200
    validation = validation_response.json()
    assert validation["valid"] is False
    assert validation["audiveris"]["configured"] is True
    assert validation["audiveris"]["available"] is False

    update_response = client.patch(
        "/api/v1/processing/settings",
        json={
            "processing_mode": "server_plus_device_and_cloud_workers",
            "allow_stub_musicxml": False,
            "local_llm_provider": "ollama",
            "local_llm_model": "qwen2.5",
            "cloud_enabled": True,
            "cloud_provider": "openai",
            "cloud_model": "gpt-test",
            "cloud_api_key": "test-secret",
        },
    )
    assert update_response.status_code == 200
    updated = update_response.json()
    assert updated["processing_mode"] == "server_plus_device_and_cloud_workers"
    assert updated["local_llm_provider"] == "ollama"
    assert updated["local_llm_model"] == "qwen2.5"
    assert updated["cloud_enabled"] is True
    assert updated["cloud_provider"] == "openai"
    assert updated["cloud_model"] == "gpt-test"
    assert updated["cloud_api_key_configured"] is True
    assert "cloud_api_key" not in updated

    register_response = client.post(
        "/api/v1/processing/device-workers/register",
        json={
            "device_id": "surface-book-dev",
            "device_name": "Surface Book Dev",
            "platform": "windows",
            "capabilities": ["tensor_omr_experiment"],
            "metadata": {"build": "debug"},
        },
    )
    assert register_response.status_code == 200
    assert register_response.json()["last_seen_at"] is not None

    capabilities_response = client.get("/api/v1/processing/capabilities")
    assert capabilities_response.status_code == 200
    capabilities = capabilities_response.json()
    assert capabilities["device_workers_enabled"] is True
    assert capabilities["cloud_workers_enabled"] is True
    assert capabilities["device_workers"][0]["device_id"] == "surface-book-dev"
    assert capabilities["local_llm"]["configured"] is True
    assert capabilities["local_llm"]["available"] is False
    assert "not implemented yet" in capabilities["local_llm"]["error"]
    assert capabilities["cloud_llm"]["configured"] is True
    assert capabilities["cloud_llm"]["available"] is True


def test_pairing_code_claim_flow(api_client) -> None:
    client, _ = api_client

    code_response = client.get("/api/v1/pairing/code")
    assert code_response.status_code == 200
    code_payload = code_response.json()
    assert code_payload["pairing_uri"].startswith("azmusic://pair?")
    assert code_payload["qr_png_url"].endswith(f"code={code_payload['pairing_code']}")
    assert code_payload["purpose"] == "student_device"

    qr_response = client.get(code_payload["qr_png_url"])
    assert qr_response.status_code == 200
    assert qr_response.headers["content-type"] == "image/png"
    assert qr_response.content.startswith(b"\x89PNG")

    claim_response = client.post(
        "/api/v1/pairing/claim",
        json={
            "pairing_code": code_payload["pairing_code"],
            "device_id": "surface-book-parent",
            "device_name": "Surface Book Parent",
            "platform": "windows",
        },
    )
    assert claim_response.status_code == 200
    claim_payload = claim_response.json()
    assert claim_payload["server_id"] == code_payload["server_id"]
    assert claim_payload["server_url"] == code_payload["server_url"]
    assert claim_payload["device_token"]
    assert claim_payload["purpose"] == "student_device"

    second_claim = client.post(
        "/api/v1/pairing/claim",
        json={
            "pairing_code": code_payload["pairing_code"],
            "device_id": "surface-book-parent",
            "device_name": "Surface Book Parent",
            "platform": "windows",
        },
    )
    assert second_claim.status_code == 404


def test_server_setup_page_hosts_pairing_qr(api_client) -> None:
    client, _ = api_client

    setup_response = client.get("/setup")
    assert setup_response.status_code == 200
    assert "Pair an AZMusic device" in setup_response.text
    assert "azmusic://pair?" in setup_response.text
    assert "parent_setup" in setup_response.text
    assert "/api/v1/pairing/code.png?code=" in setup_response.text


def test_student_device_pairing_code_includes_profile_assignment(api_client) -> None:
    client, _ = api_client

    code_response = client.get(
        "/api/v1/pairing/code",
        params={
            "purpose": "student_device",
            "profile_id": "student-alyse",
            "profile_name": "Alyse",
            "role": "student",
        },
    )
    assert code_response.status_code == 200
    code_payload = code_response.json()
    assert code_payload["profile_id"] == "student-alyse"
    assert code_payload["profile_name"] == "Alyse"
    assert code_payload["role"] == "student"
    assert "profile_id=student-alyse" in code_payload["pairing_uri"]

    claim_response = client.post(
        "/api/v1/pairing/claim",
        json={
            "pairing_code": code_payload["pairing_code"],
            "device_id": "alyse-tablet",
            "device_name": "Alyse Tablet",
            "platform": "android",
        },
    )
    assert claim_response.status_code == 200
    claim_payload = claim_response.json()
    assert claim_payload["profile_id"] == "student-alyse"
    assert claim_payload["role"] == "student"


def test_protected_routes_can_require_qr_paired_device_tokens(
    api_client,
    monkeypatch,
) -> None:
    client, _ = api_client
    monkeypatch.setattr(settings, "require_device_auth", True)

    unpaired_response = client.get("/api/v1/pieces/")
    assert unpaired_response.status_code == 401
    assert "Paired device token required" in unpaired_response.json()["detail"]

    code_response = client.get(
        "/api/v1/pairing/code",
        params={
            "purpose": "student_device",
            "profile_id": "student-cello",
            "profile_name": "Cello Student",
            "role": "student",
        },
    )
    assert code_response.status_code == 200
    claim_response = client.post(
        "/api/v1/pairing/claim",
        json={
            "pairing_code": code_response.json()["pairing_code"],
            "device_id": "student-tablet",
            "device_name": "Student Tablet",
            "platform": "android",
        },
    )
    assert claim_response.status_code == 200
    token = claim_response.json()["device_token"]

    paired_response = client.get(
        "/api/v1/pieces/",
        headers={"X-AZMusic-Device-Token": token},
    )
    assert paired_response.status_code == 200


def test_production_processing_mode_requires_real_tools(
    api_client,
    monkeypatch,
) -> None:
    client, storage_path = api_client
    monkeypatch.setattr(settings, "production_mode", True)

    missing_audiveris = storage_path / "missing-audiveris.exe"
    missing_musescore = storage_path / "missing-musescore.exe"
    missing_tesseract = storage_path / "missing-tesseract.exe"
    settings_response = client.patch(
        "/api/v1/processing/settings",
        json={
            "allow_stub_musicxml": True,
            "audiveris_cli_path": str(missing_audiveris),
            "musescore_cli_path": str(missing_musescore),
            "ocr_cli_path": str(missing_tesseract),
        },
    )
    assert settings_response.status_code == 200
    settings_payload = settings_response.json()
    assert settings_payload["production_mode"] is True
    assert settings_payload["allow_stub_musicxml"] is False

    validation_response = client.post("/api/v1/processing/settings/validate", json={})
    assert validation_response.status_code == 200
    validation = validation_response.json()
    assert validation["valid"] is False
    assert any(
        "Production processing requires Audiveris" in item for item in validation["warnings"]
    )
    assert any(
        "Production processing requires MuseScore" in item for item in validation["warnings"]
    )
    assert any(
        "Production processing requires Tesseract OCR" in item for item in validation["warnings"]
    )

    import_response = client.post(
        "/api/v1/pieces/import",
        data={"title": "Production Gate Study"},
        files={
            "file": (
                "production_gate_study.pdf",
                b"%PDF-1.4\n%AZMusic production gate\n",
                "application/pdf",
            )
        },
    )
    assert import_response.status_code == 409
    assert (
        "Production processing requires configured real tools" in import_response.json()["detail"]
    )


def test_metadata_edits_refresh_pending_review_musicxml(api_client) -> None:
    client, _ = api_client

    import_response = client.post(
        "/api/v1/pieces/import",
        data={"title": "Untitled Piece", "composer": "Unknown"},
        files={
            "file": (
                "untitled_piece.pdf",
                b"%PDF-1.4\n%AZMusic metadata refresh\n",
                "application/pdf",
            )
        },
    )
    assert import_response.status_code == 200
    piece_id = import_response.json()["id"]
    review_item = next(
        item for item in client.get("/api/v1/review/").json() if item["piece_id"] == piece_id
    )

    update_response = client.patch(
        f"/api/v1/pieces/{piece_id}",
        json={
            "title": "Corrected Jig",
            "composer": "Traditional",
            "primary_instrument": "Cello",
        },
    )
    assert update_response.status_code == 200
    updated_piece = update_response.json()
    assert updated_piece["title"] == "Corrected Jig"
    assert updated_piece["composer"] == "Traditional"
    assert updated_piece["primary_instrument"] == "Cello"

    refreshed_item = client.get(f"/api/v1/review/{review_item['id']}").json()
    candidate_data = refreshed_item["candidate_data"]
    assert candidate_data["catalog_metadata"]["title"] == "Corrected Jig"
    assert candidate_data["catalog_metadata"]["composer"] == "Traditional"
    assert candidate_data["processed_metadata"]["title"] == "Corrected Jig"
    assert candidate_data["processed_metadata"]["composer"] == "Traditional"
    assert candidate_data["processed_metadata"]["primary_instrument"] == "Cello"
    assert candidate_data["metadata_rerendered_at"]

    canonical_response = client.get(candidate_data["canonical_file_url"])
    assert canonical_response.status_code == 200
    canonical_text = canonical_response.text
    assert "Corrected Jig" in canonical_text
    assert "Traditional" in canonical_text
    assert "Cello" in canonical_text


def test_pdf_import_preserves_raw_when_required_engine_is_missing(api_client) -> None:
    client, storage_path = api_client

    settings_response = client.patch(
        "/api/v1/processing/settings",
        json={"allow_stub_musicxml": False, "audiveris_cli_path": None},
    )
    assert settings_response.status_code == 200

    import_response = client.post(
        "/api/v1/pieces/import",
        data={
            "title": "Engine Missing Study",
            "composer": "Debug Composer",
        },
        files={
            "file": (
                "engine_missing_study.pdf",
                b"%PDF-1.4\n%AZMusic missing engine\n",
                "application/pdf",
            )
        },
    )
    assert import_response.status_code == 200
    piece = import_response.json()
    piece_id = piece["id"]
    assert piece["status"] == "imported"

    detail_response = client.get(f"/api/v1/pieces/{piece_id}")
    assert detail_response.status_code == 200
    detail = detail_response.json()
    assert len(detail["score_versions"]) == 1
    assert detail["score_versions"][0]["version_type"] == "raw"
    assert (storage_path / "pieces" / piece_id / "raw_source.pdf").exists()

    jobs_response = client.get("/api/v1/jobs/")
    assert jobs_response.status_code == 200
    job = next(job for job in jobs_response.json() if job["piece_id"] == piece_id)
    assert job["status"] == "failed"
    assert "Audiveris is not configured" in job["error_message"]

    settings_after_failure = client.get("/api/v1/processing/settings").json()
    assert "Audiveris is not configured" in settings_after_failure["last_processing_error"]
