import asyncio
import hashlib
import json
from io import BytesIO
from pathlib import Path
from xml.etree import ElementTree

import pytest
import server.database as database_module
import server.main as main_module
import server.routers.pieces as pieces_router_module
import server.services.processing_settings as processing_settings_module
import server.services.server_urls as server_urls_module
from fastapi.testclient import TestClient
from PIL import Image, ImageDraw
from pypdf import PdfReader, PdfWriter
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


def _shared_two_piece_pdf_bytes() -> bytes:
    image = Image.new("RGB", (612, 792), "white")
    draw = ImageDraw.Draw(image)
    for system_y in (120, 230, 340, 520, 630, 730):
        for staff_line in range(5):
            y = system_y + staff_line * 5
            draw.line((80, y, 535, y), fill="black", width=2)
    output = BytesIO()
    image.save(output, format="PDF", resolution=72)
    return output.getvalue()


def _two_part_musicxml(title: str, measure_count: int) -> str:
    measures = "\n".join(
        f"""
        <measure number="{measure_number}" width="{220 + measure_number}">
          <print>
            <system-layout><system-distance>126</system-distance></system-layout>
            <staff-layout number="1"><staff-distance>85</staff-distance></staff-layout>
          </print>
          <note default-x="{18 + measure_number}">
            <pitch><step>D</step><octave>3</octave></pitch>
            <duration>1</duration>
            <type>quarter</type>
          </note>
        </measure>
        """
        for measure_number in range(1, measure_count + 1)
    )
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <work><work-title>{title}</work-title></work>
  <movement-title>{title}</movement-title>
  <part-list>
    <score-part id="P1"><part-name>Cello</part-name></score-part>
    <score-part id="P2"><part-name>Cello</part-name></score-part>
  </part-list>
  <part id="P1">{measures}</part>
  <part id="P2">{measures}</part>
</score-partwise>
"""


def _xml_local_name(node) -> str:
    return node.tag.rsplit("}", maxsplit=1)[-1]


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
    monkeypatch.setattr(settings, "audiveris_cli_path", None)
    monkeypatch.setattr(settings, "musescore_cli_path", None)
    monkeypatch.setattr(settings, "ocr_cli_path", None)
    monkeypatch.setenv("ProgramFiles", str(tmp_path / "empty-program-files"))
    monkeypatch.setenv("ProgramFiles(x86)", str(tmp_path / "empty-program-files-x86"))
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


def test_ocr_metadata_parser_rejects_music_notation_noise_as_composer() -> None:
    playing = infer_metadata_from_text(
        """
        62 Playing in the Park
        J = 120
        4 1 a 0 Ket eee Pa
        SSS WP NU 2 2 5s oa tl
        D.C. al Fine
        """
    )
    landler = infer_metadata_from_text(
        """
        56 Landler
        J = 104
        a ©. ~~ 4 Vv
        OOo Ee
        D.C. al Fine
        """
    )

    assert playing["title"] == "Playing in the Park"
    assert "composer" not in playing
    assert "catalog_number" not in playing
    assert landler["title"] == "Landler"
    assert "composer" not in landler
    assert "publisher" not in landler


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

    class FakeBookPreprocessor:
        def __init__(self, processing_settings) -> None:
            pass

        def preprocess(self, *, file_name: str, file_bytes: bytes):
            return book_preprocessing_module.BookPreprocessingResult(
                page_count=2,
                page_facts=[],
                split_proposals=[],
                book_metadata={
                    "title": "Suzuki Violin School Volume 1",
                    "composer": "Shinichi Suzuki",
                    "primary_instrument": "Violin",
                    "source_file_name": file_name,
                },
            )

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

    monkeypatch.setattr(score_processing_module, "BookPreprocessor", FakeBookPreprocessor)
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
    assert assigned_piece["workflow_closed"] is False

    close_response = client.post(f"/api/v1/pieces/{piece_id}/workflow/close")
    assert close_response.status_code == 200
    closed_piece = close_response.json()
    assert closed_piece["library_status"] == "ready"
    assert closed_piece["workflow_closed"] is True
    assert closed_piece["visible_to_profile_ids"] == ["student-alyse"]

    assigned_after_close = client.get("/api/v1/pieces/assigned/student-alyse")
    assert assigned_after_close.status_code == 200
    assigned_closed = next(item for item in assigned_after_close.json() if item["id"] == piece_id)
    assert assigned_closed["library_status"] == "ready"
    assert assigned_closed["workflow_closed"] is True

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


def test_parent_can_compare_and_approve_alternate_omr_candidate(
    api_client,
    monkeypatch,
) -> None:
    client, _ = api_client

    def fake_generate(
        self,
        *,
        raw_pdf_path,
        output_path,
        title,
        composer,
        primary_instrument=None,
        contained_piece_titles=None,
        multi_piece_page=False,
        processing_settings,
    ):
        del self, raw_pdf_path, contained_piece_titles, multi_piece_page, processing_settings
        output_path.write_text(
            processing_engines_module._build_stub_musicxml(
                title=title,
                composer=composer,
                primary_instrument=primary_instrument or "Cello",
                measure_count=2,
            ),
            encoding="utf-8",
        )
        homr_path = output_path.with_name("candidate_homr.musicxml")
        homr_path.write_text(
            processing_engines_module._build_stub_musicxml(
                title=f"{title} HOMR",
                composer=composer,
                primary_instrument=primary_instrument or "Cello",
                measure_count=4,
            ),
            encoding="utf-8",
        )
        metadata = processing_engines_module._validate_musicxml(output_path)
        homr_metadata = processing_engines_module._validate_musicxml(homr_path)
        audiveris_metadata = dict(metadata)
        metadata["omr_quality_score"] = 25.0
        metadata["omr_attempts"] = [
            {
                "engine": "audiveris",
                "profile": "default",
                "candidate_path": str(output_path),
                "metadata": audiveris_metadata,
                "quality_score": 25.0,
            },
            {
                "engine": "homr",
                "profile": "experimental",
                "candidate_path": str(homr_path),
                "metadata": homr_metadata,
                "quality_score": 45.0,
                "warnings": ["HOMR candidate produced by test bakeoff."],
            },
        ]
        return processing_engines_module.MusicXmlResult(
            file_path=output_path,
            engine_name="audiveris",
            engine_version="test-audiveris",
            provenance="audiveris_omr",
            confidence=0.82,
            warnings=["Audiveris candidate produced by test bakeoff."],
            metadata=metadata,
        )

    def fake_render(
        self,
        *,
        canonical_path,
        raw_pdf_path,
        output_pdf_path,
        processing_settings,
    ):
        del self, canonical_path, raw_pdf_path, processing_settings
        pdf_bytes = _valid_pdf_bytes()
        output_pdf_path.write_bytes(pdf_bytes)
        return processing_engines_module.RenderResult(
            file_path=output_pdf_path,
            renderer_name="test_musescore",
            renderer_version="test-renderer",
            provenance="musescore_render",
            warnings=[],
            validation_status="valid",
            validation_error=None,
            file_size_bytes=len(pdf_bytes),
            page_count=1,
            diagnostics={"test_renderer": True},
        )

    monkeypatch.setattr(score_processing_module.MusicXmlEngine, "generate", fake_generate)
    monkeypatch.setattr(
        score_processing_module.MuseScoreRenderEngine,
        "render",
        fake_render,
    )

    import_response = client.post(
        "/api/v1/pieces/import",
        data={"title": "Bakeoff Study", "primary_instrument": "Cello"},
        files={"file": ("bakeoff_study.pdf", _valid_pdf_bytes(), "application/pdf")},
    )
    assert import_response.status_code == 200
    piece_id = import_response.json()["id"]

    review_item = next(
        item for item in client.get("/api/v1/review/").json() if item["piece_id"] == piece_id
    )
    candidate_data = review_item["candidate_data"]
    candidates = candidate_data["omr_candidates"]
    assert len(candidates) == 2
    assert candidate_data["selected_omr_candidate_id"] == "selected_best"
    assert {candidate["engine_name"] for candidate in candidates} == {"audiveris", "homr"}

    homr_candidate = next(
        candidate for candidate in candidates if candidate["engine_name"] == "homr"
    )
    assert homr_candidate["rendered_file_url"].endswith("/file")
    assert homr_candidate["canonical_file_url"].endswith("/file")
    assert homr_candidate["omr_quality_score"] == 45.0

    approve_response = client.post(
        f"/api/v1/review/{review_item['id']}",
        json={
            "action": "approve",
            "selected_candidate_id": homr_candidate["candidate_id"],
        },
    )
    assert approve_response.status_code == 200
    approved_candidate_data = approve_response.json()["candidate_data"]
    assert approved_candidate_data["selected_omr_candidate_id"] == homr_candidate["candidate_id"]
    assert approved_candidate_data["engine_name"] == "homr"
    assert approved_candidate_data["score_version_id"] == homr_candidate["score_version_id"]

    detail = client.get(f"/api/v1/pieces/{piece_id}").json()
    default_version = next(version for version in detail["score_versions"] if version["is_default"])
    assert default_version["id"] == homr_candidate["score_version_id"]
    canonical_version = next(
        version
        for version in detail["score_versions"]
        if version["id"] == homr_candidate["canonical_score_version_id"]
    )
    assert canonical_version["version_type"] == "approved"


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


def test_musescore_render_forces_export_and_records_diagnostics(
    tmp_path,
    monkeypatch,
) -> None:
    canonical_path = tmp_path / "candidate.musicxml"
    raw_path = tmp_path / "raw_source.pdf"
    output_path = tmp_path / "candidate_review.pdf"
    canonical_path.write_text(
        processing_engines_module._build_stub_musicxml(
            title="Landler",
            composer="Rick Mooney",
            primary_instrument="Cello",
            measure_count=1,
        ),
        encoding="utf-8",
    )
    raw_path.write_bytes(_valid_pdf_bytes())
    fake_musescore = tmp_path / "MuseScore4.exe"
    fake_musescore.write_text("fake", encoding="utf-8")
    commands = []

    class FakeExecutableStatus:
        discovered_path = str(fake_musescore)
        version = "MuseScore4 4.7.1"

    class FakeRunResult:
        returncode = 0
        stdout = "rendered"
        stderr = ""

    def fake_executable_status(**_kwargs):
        return FakeExecutableStatus()

    def fake_run(command, **kwargs):
        commands.append(command)
        assert kwargs["timeout"] == 300
        output_path.write_bytes(_valid_pdf_bytes())
        return FakeRunResult()

    monkeypatch.setattr(processing_engines_module, "executable_status", fake_executable_status)
    monkeypatch.setattr(processing_engines_module.subprocess, "run", fake_run)

    render_result = processing_engines_module.MuseScoreRenderEngine().render(
        canonical_path=canonical_path,
        raw_pdf_path=raw_path,
        output_pdf_path=output_path,
        processing_settings={"musescore_cli_path": str(fake_musescore)},
    )

    assert commands[0][:2] == [str(fake_musescore), "-S"]
    assert commands[0][3:] == ["-f", str(canonical_path), "-o", str(output_path)]
    assert render_result.validation_status == "valid"
    assert render_result.diagnostics["command"] == commands[0]
    assert render_result.diagnostics["style_source"] == "azmusic_default"
    assert render_result.diagnostics["style_applied"] is True
    assert render_result.diagnostics["exit_code"] == 0
    assert render_result.diagnostics["stdout_excerpt"] == "rendered"
    assert render_result.diagnostics["validation_status"] == "valid"


def test_musescore_render_failure_includes_exit_code_diagnostics(
    tmp_path,
    monkeypatch,
) -> None:
    canonical_path = tmp_path / "candidate.musicxml"
    raw_path = tmp_path / "raw_source.pdf"
    output_path = tmp_path / "candidate_review.pdf"
    canonical_path.write_text(
        processing_engines_module._build_stub_musicxml(
            title="Landler",
            composer="Rick Mooney",
            primary_instrument="Cello",
            measure_count=1,
        ),
        encoding="utf-8",
    )
    raw_path.write_bytes(_valid_pdf_bytes())
    fake_musescore = tmp_path / "MuseScore4.exe"
    fake_musescore.write_text("fake", encoding="utf-8")

    class FakeExecutableStatus:
        discovered_path = str(fake_musescore)
        version = "MuseScore4 4.7.1"

    class FakeRunResult:
        returncode = 1320
        stdout = ""
        stderr = ""

    monkeypatch.setattr(
        processing_engines_module,
        "executable_status",
        lambda **_kwargs: FakeExecutableStatus(),
    )
    monkeypatch.setattr(
        processing_engines_module.subprocess,
        "run",
        lambda *_args, **_kwargs: FakeRunResult(),
    )

    with pytest.raises(processing_engines_module.ProcessingEngineError) as exc_info:
        processing_engines_module.MuseScoreRenderEngine().render(
            canonical_path=canonical_path,
            raw_pdf_path=raw_path,
            output_pdf_path=output_path,
            processing_settings={"musescore_cli_path": str(fake_musescore)},
        )

    assert "exit code 1320" in str(exc_info.value)
    assert exc_info.value.diagnostics["exit_code"] == 1320
    assert exc_info.value.diagnostics["output_exists"] is False


def test_render_blocked_candidate_keeps_musicxml_and_requires_rerender(
    api_client,
    monkeypatch,
) -> None:
    client, storage_path = api_client

    def fake_empty_render(
        self, *, canonical_path, raw_pdf_path, output_pdf_path, processing_settings
    ):
        output_pdf_path.write_bytes(b"")
        raise processing_engines_module.ProcessingEngineError(
            "MuseScore did not produce a usable review PDF: Rendered PDF is empty."
        )

    monkeypatch.setattr(
        score_processing_module.MuseScoreRenderEngine,
        "render",
        fake_empty_render,
    )

    import_response = client.post(
        "/api/v1/pieces/import",
        data={"title": "Blocked Render Study", "composer": "Server Test"},
        files={
            "file": (
                "blocked_render_study.pdf",
                _valid_pdf_bytes(),
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
    candidate_data = review_item["candidate_data"]
    assert candidate_data["render_validation_status"] == "render_failed"
    assert "Rendered PDF is empty" in candidate_data["render_validation_error"]
    assert "rendered_file_url" not in candidate_data
    assert (storage_path / "pieces" / piece_id / "candidate.musicxml").exists()

    failed_jobs = [job for job in client.get("/api/v1/jobs/").json() if job["piece_id"] == piece_id]
    assert failed_jobs[0]["status"] == "failed"
    assert "Rendered PDF is empty" in failed_jobs[0]["error_message"]

    approve_response = client.post(
        f"/api/v1/review/{review_item['id']}",
        json={"action": "approve"},
    )
    assert approve_response.status_code == 409

    def fake_valid_render(
        self, *, canonical_path, raw_pdf_path, output_pdf_path, processing_settings
    ):
        output_pdf_path.write_bytes(_valid_pdf_bytes())
        return processing_engines_module.RenderResult(
            file_path=output_pdf_path,
            renderer_name="musescore",
            renderer_version="test-renderer",
            provenance="musescore_render",
            warnings=[],
            validation_status="valid",
            file_size_bytes=output_pdf_path.stat().st_size,
            page_count=1,
        )

    monkeypatch.setattr(
        pieces_router_module.MuseScoreRenderEngine,
        "render",
        fake_valid_render,
    )
    rerender_response = client.post(
        f"/api/v1/pieces/{piece_id}/score_versions/{canonical_version['id']}/rerender",
        json={"rendered_score_version_id": rendered_version["id"]},
    )
    assert rerender_response.status_code == 200
    assert rerender_response.json()["render_validation_status"] == "valid"

    refreshed_item = client.get(f"/api/v1/review/{review_item['id']}").json()
    refreshed_candidate = refreshed_item["candidate_data"]
    assert refreshed_candidate["render_validation_status"] == "valid"
    assert refreshed_candidate["rendered_file_url"]

    approve_response = client.post(
        f"/api/v1/review/{review_item['id']}",
        json={"action": "approve"},
    )
    assert approve_response.status_code == 200


def test_retry_failed_render_job_reuses_existing_musicxml(
    api_client,
    monkeypatch,
) -> None:
    client, storage_path = api_client

    def fake_blocked_render(
        self, *, canonical_path, raw_pdf_path, output_pdf_path, processing_settings
    ):
        output_pdf_path.write_bytes(b"")
        raise processing_engines_module.ProcessingEngineError(
            "MuseScore Studio failed with exit code 1320 without returning diagnostic output.",
            diagnostics={
                "command": ["MuseScore4.exe", str(canonical_path), "-o", str(output_pdf_path)],
                "exit_code": 1320,
                "output_exists": False,
            },
        )

    monkeypatch.setattr(
        score_processing_module.MuseScoreRenderEngine,
        "render",
        fake_blocked_render,
    )

    import_response = client.post(
        "/api/v1/pieces/import",
        data={"title": "Landler", "composer": "Rick Mooney"},
        files={
            "file": (
                "landler.pdf",
                _valid_pdf_bytes(),
                "application/pdf",
            )
        },
    )
    assert import_response.status_code == 200
    piece_id = import_response.json()["id"]
    failed_job = next(
        job for job in client.get("/api/v1/jobs/").json() if job["piece_id"] == piece_id
    )
    assert failed_job["status"] == "failed"
    assert failed_job["result_data"]["render_diagnostics"]["exit_code"] == 1320

    retry_response = client.post(f"/api/v1/jobs/{failed_job['id']}/retry")
    assert retry_response.status_code == 200
    retried = retry_response.json()
    assert retried["status"] == "queued"
    assert retried["result_data"]["retry_mode"] == "render_only"

    render_calls = []

    def fail_if_omr_runs(self, **_kwargs):
        raise AssertionError("render-only retry should not regenerate MusicXML")

    def fake_valid_render(
        self, *, canonical_path, raw_pdf_path, output_pdf_path, processing_settings
    ):
        render_calls.append((canonical_path, raw_pdf_path, output_pdf_path))
        output_pdf_path.write_bytes(_valid_pdf_bytes())
        return processing_engines_module.RenderResult(
            file_path=output_pdf_path,
            renderer_name="musescore",
            renderer_version="MuseScore4 4.7.1",
            provenance="musescore_render",
            warnings=[],
            validation_status="valid",
            validation_error=None,
            file_size_bytes=output_pdf_path.stat().st_size,
            page_count=1,
            diagnostics={
                "command": [
                    "MuseScore4.exe",
                    "-f",
                    str(canonical_path),
                    "-o",
                    str(output_pdf_path),
                ],
                "exit_code": 0,
                "validation_status": "valid",
            },
        )

    monkeypatch.setattr(score_processing_module.MusicXmlEngine, "generate", fail_if_omr_runs)
    monkeypatch.setattr(
        score_processing_module.MuseScoreRenderEngine,
        "render",
        fake_valid_render,
    )

    processed = asyncio.run(JobDispatcher(poll_interval_seconds=0.01).run_once())
    assert processed is True
    assert len(render_calls) == 1
    assert render_calls[0][0] == storage_path / "pieces" / piece_id / "candidate.musicxml"

    refreshed_job = client.get(f"/api/v1/jobs/{failed_job['id']}").json()
    assert refreshed_job["status"] == "succeeded"
    assert refreshed_job["result_data"]["render_validation_status"] == "valid"
    assert refreshed_job["result_data"]["render_diagnostics"]["exit_code"] == 0

    refreshed_item = next(
        item for item in client.get("/api/v1/review/").json() if item["piece_id"] == piece_id
    )
    candidate_data = refreshed_item["candidate_data"]
    assert candidate_data["render_validation_status"] == "valid"
    assert candidate_data["render_diagnostics"]["exit_code"] == 0
    assert "rendered_file_url" in candidate_data


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


def test_book_preprocessing_uses_title_ocr_for_standalone_inner_titles() -> None:
    candidates = book_preprocessing_module._title_candidates(
        "Fanfare\nay\ncy\nae",
        [],
        title_ocr_text="Fanfare\n\nd=120\n\nSkating\n\n=108",
    )

    assert candidates[:2] == ["Fanfare", "Skating"]

    proposals = book_preprocessing_module._propose_splits(
        [
            book_preprocessing_module.BookPageFact(
                page_number=6,
                text="Fanfare",
                text_excerpt="Fanfare",
                classification="music_piece",
                title_candidates=candidates,
                has_staff_hint=True,
                dark_pixel_ratio=0.05,
                horizontal_line_count=45,
            )
        ],
        {
            "composer": "Rick Mooney",
            "primary_instrument": "Cello",
        },
    )

    assert proposals[0].title == "Fanfare / Skating"
    assert proposals[0].contained_piece_titles == ["Fanfare", "Skating"]
    assert proposals[0].multi_piece_page is True


def test_book_preprocessing_uses_title_ocr_when_default_ocr_misses_title() -> None:
    candidates = book_preprocessing_module._title_candidates(
        "Fine",
        [],
        title_ocr_text="Jig\n\n4 2\n\nFine",
    )

    assert candidates == ["Jig"]


def test_multi_piece_staff_split_boundary_prefers_shared_page_separator() -> None:
    page_39_centers = [
        113,
        132,
        224,
        233,
        244,
        255,
        265,
        355,
        366,
        376,
        387,
        398,
        532,
        543,
        554,
        564,
        575,
        665,
        676,
        686,
        697,
        708,
        768,
        774,
        965,
        975,
        986,
        997,
        1007,
        1097,
        1108,
        1115,
        1128,
        1139,
        1272,
        1283,
        1293,
        1304,
        1314,
        1404,
        1414,
        1424,
        1434,
        1445,
    ]

    boundaries = score_processing_module._multi_piece_staff_split_boundaries(
        page_39_centers,
        page_height=1584,
        piece_count=2,
    )

    assert len(boundaries) == 1
    assert 820 <= boundaries[0] <= 910


def test_multi_piece_split_boundary_moves_above_second_heading() -> None:
    image = Image.new("RGB", (612, 792), "white")
    draw = ImageDraw.Draw(image)
    draw.rectangle((246, 420, 366, 450), fill="black")

    boundaries = score_processing_module._refine_multi_piece_boundaries_for_heading_text(
        image,
        [435],
        piece_count=2,
    )

    assert len(boundaries) == 1
    assert 400 <= boundaries[0] < 420


def test_multi_piece_omr_input_splits_shared_page_pdf(tmp_path) -> None:
    raw_pdf_path = tmp_path / "shared.pdf"
    output_path = tmp_path / "omr_input.pdf"
    raw_pdf_path.write_bytes(_shared_two_piece_pdf_bytes())

    omr_path, warnings = score_processing_module._prepare_multi_piece_omr_input_pdf(
        raw_pdf_path=raw_pdf_path,
        output_path=output_path,
        piece_titles=["The Troubadour", "Hoedown"],
    )

    assert omr_path == output_path
    assert score_processing_module._pdf_page_count(output_path) == 2
    assert any("OMR crop input" in warning for warning in warnings)


def test_multi_piece_omr_piece_pdfs_split_shared_page_pdf(tmp_path) -> None:
    raw_pdf_path = tmp_path / "shared.pdf"
    output_dir = tmp_path / "omr_inputs"
    raw_pdf_path.write_bytes(_shared_two_piece_pdf_bytes())

    omr_paths, warnings = score_processing_module._prepare_multi_piece_omr_piece_pdfs(
        raw_pdf_path=raw_pdf_path,
        output_dir=output_dir,
        piece_titles=["The Troubadour", "Hoedown"],
    )

    assert [path.name for path in omr_paths] == ["omr_piece_01.pdf", "omr_piece_02.pdf"]
    assert all(score_processing_module._pdf_page_count(path) == 1 for path in omr_paths)
    assert any("separate OMR input" in warning for warning in warnings)


def test_omr_spacing_normalization_strips_audiveris_layout_hints(tmp_path) -> None:
    raw_path = tmp_path / "audiveris.musicxml"
    output_path = tmp_path / "candidate.musicxml"
    raw_path.write_text(_two_part_musicxml("Landler", 2), encoding="utf-8")

    normalized = processing_engines_module._normalize_result_metadata(
        processing_engines_module.MusicXmlResult(
            file_path=raw_path,
            engine_name="audiveris",
            engine_version="test",
            provenance="audiveris_omr",
            confidence=0.82,
            metadata={"part_count": 2, "primary_instrument": "Voice"},
        ),
        output_path=output_path,
        title="Landler",
        composer="Rick Mooney",
        primary_instrument="Cello",
    )

    root = ElementTree.parse(normalized.file_path).getroot()
    assert all(
        "width" not in node.attrib for node in root.iter() if _xml_local_name(node) == "measure"
    )
    assert all(
        "default-x" not in node.attrib for node in root.iter() if _xml_local_name(node) == "note"
    )
    assert not any(_xml_local_name(node) == "system-layout" for node in root.iter())
    assert not any(_xml_local_name(node) == "staff-layout" for node in root.iter())
    assert normalized.metadata["spacing_normalization_applied"] is True
    assert normalized.metadata["spacing_normalization_profile"] == "balanced_omr"
    assert normalized.metadata["spacing_normalization_changes"] == {
        "measure_width_attributes_removed": 4,
        "note_default_x_attributes_removed": 4,
        "system_layout_elements_removed": 4,
        "staff_layout_elements_removed": 4,
    }
    assert normalized.metadata["primary_instrument"] == "Cello"
    assert normalized.metadata["composer"] == "Rick Mooney"


def test_musicxml_normalization_preserves_omr_attempts_for_candidate_compare(tmp_path) -> None:
    raw_path = tmp_path / "audiveris.musicxml"
    output_path = tmp_path / "candidate.musicxml"
    raw_path.write_text(_two_part_musicxml("Bakeoff Study", 2), encoding="utf-8")
    attempts = [
        {
            "engine": "audiveris",
            "profile": "default",
            "candidate_path": str(raw_path),
            "quality_score": 7.25,
        },
        {
            "engine": "homr",
            "profile": "experimental",
            "candidate_path": str(tmp_path / "candidate_homr.musicxml"),
            "quality_score": 8.5,
        },
    ]

    normalized = processing_engines_module._normalize_result_metadata(
        processing_engines_module.MusicXmlResult(
            file_path=raw_path,
            engine_name="audiveris",
            engine_version="test",
            provenance="audiveris_omr",
            confidence=0.82,
            metadata={
                "omr_strategy": "experimental_engine_bakeoff",
                "omr_quality_score": 8.5,
                "omr_attempts": attempts,
            },
        ),
        output_path=output_path,
        title="Bakeoff Study",
        composer="Test Composer",
        primary_instrument="Cello",
    )

    assert normalized.metadata["omr_strategy"] == "experimental_engine_bakeoff"
    assert normalized.metadata["omr_quality_score"] == 8.5
    assert normalized.metadata["omr_attempts"] == attempts


def test_musicxml_normalization_sanitizes_recursive_omr_attempt_metadata(tmp_path) -> None:
    raw_path = tmp_path / "audiveris.musicxml"
    output_path = tmp_path / "candidate.musicxml"
    raw_path.write_text(_two_part_musicxml("Bakeoff Study", 2), encoding="utf-8")
    attempts = [
        {
            "engine": "homr",
            "profile": "experimental",
            "candidate_path": str(tmp_path / "candidate_homr.musicxml"),
            "quality_score": 8.5,
        }
    ]
    attempts[0]["metadata"] = {"omr_attempts": attempts}

    normalized = processing_engines_module._normalize_result_metadata(
        processing_engines_module.MusicXmlResult(
            file_path=raw_path,
            engine_name="audiveris",
            engine_version="test",
            provenance="audiveris_omr",
            confidence=0.82,
            metadata={
                "omr_strategy": "experimental_engine_bakeoff",
                "omr_quality_score": 8.5,
                "omr_attempts": attempts,
            },
        ),
        output_path=output_path,
        title="Bakeoff Study",
        composer="Test Composer",
        primary_instrument="Cello",
    )

    assert normalized.metadata["omr_attempts"][0]["engine"] == "homr"
    assert normalized.metadata["omr_attempts"][0]["candidate_path"].endswith(
        "candidate_homr.musicxml"
    )
    assert "metadata" not in normalized.metadata["omr_attempts"][0]
    json.dumps(normalized.metadata)


def test_multi_piece_segment_merge_keeps_crops_sequential(
    tmp_path,
    monkeypatch,
) -> None:
    raw_paths = [tmp_path / "piece_1.pdf", tmp_path / "piece_2.pdf"]
    for raw_path in raw_paths:
        raw_path.write_bytes(_valid_pdf_bytes())

    def fake_generate(self, **kwargs):
        title = kwargs["title"]
        output_path = kwargs["output_path"]
        measure_count = 2 if title == "The Troubadour" else 3
        output_path.write_text(
            _two_part_musicxml(title, measure_count),
            encoding="utf-8",
        )
        return processing_engines_module.MusicXmlResult(
            file_path=output_path,
            engine_name="audiveris",
            engine_version="test",
            provenance="audiveris_omr",
            confidence=0.82,
            warnings=[],
            metadata={"title": title, "part_count": 2, "measure_count": measure_count},
        )

    monkeypatch.setattr(processing_engines_module.MusicXmlEngine, "generate", fake_generate)

    output_path = tmp_path / "candidate.musicxml"
    result = processing_engines_module.MusicXmlEngine().generate_multi_piece_segments(
        raw_pdf_paths=raw_paths,
        output_path=output_path,
        title="The Troubadour / Hoedown",
        composer="Rick Mooney",
        primary_instrument="Cello",
        contained_piece_titles=["The Troubadour", "Hoedown"],
        processing_settings={"allow_stub_musicxml": False},
    )

    root = ElementTree.parse(output_path).getroot()
    parts = [child for child in list(root) if child.tag.rsplit("}", maxsplit=1)[-1] == "part"]
    assert len(parts) == 2
    for part in parts:
        measures = [
            child for child in list(part) if child.tag.rsplit("}", maxsplit=1)[-1] == "measure"
        ]
        assert len(measures) == 5

    first_part_measures = [
        child for child in list(parts[0]) if child.tag.rsplit("}", maxsplit=1)[-1] == "measure"
    ]
    assert [measure.attrib["number"] for measure in first_part_measures] == [
        "1",
        "2",
        "1",
        "2",
        "3",
    ]
    boundary_measure = first_part_measures[2]
    assert any(
        child.tag.rsplit("}", maxsplit=1)[-1] == "print" and child.attrib.get("new-system") == "yes"
        for child in list(boundary_measure)
    )
    assert any(
        words.tag.rsplit("}", maxsplit=1)[-1] == "words" and words.text == "Hoedown"
        for words in boundary_measure.iter()
    )

    page_layout = next(
        node for node in root.iter() if node.tag.rsplit("}", maxsplit=1)[-1] == "page-layout"
    )
    page_height = next(
        child
        for child in list(page_layout)
        if child.tag.rsplit("}", maxsplit=1)[-1] == "page-height"
    )
    page_width = next(
        child
        for child in list(page_layout)
        if child.tag.rsplit("}", maxsplit=1)[-1] == "page-width"
    )
    assert int(page_height.text) > int(page_width.text)
    assert all(
        "width" not in node.attrib for node in root.iter() if _xml_local_name(node) == "measure"
    )
    assert all(
        "default-x" not in node.attrib for node in root.iter() if _xml_local_name(node) == "note"
    )
    assert not any(_xml_local_name(node) == "system-layout" for node in root.iter())
    assert not any(_xml_local_name(node) == "staff-layout" for node in root.iter())
    assert result.provenance == "audiveris_omr_segment_merge"
    assert result.metadata["multi_piece_segment_count"] == 2
    assert result.metadata["primary_instrument"] == "Cello"
    assert result.metadata["spacing_normalization_applied"] is True
    assert result.metadata["spacing_normalization_profile"] == "balanced_omr"
    assert result.metadata["spacing_normalization_changes"] == {
        "measure_width_attributes_removed": 10,
        "note_default_x_attributes_removed": 10,
        "system_layout_elements_removed": 10,
        "staff_layout_elements_removed": 10,
    }

    renormalized = processing_engines_module._normalize_result_metadata(
        result,
        output_path=tmp_path / "candidate.final.musicxml",
        title="The Troubadour / Hoedown",
        composer="Rick Mooney",
        primary_instrument="Cello",
        contained_piece_titles=["The Troubadour", "Hoedown"],
        multi_piece_page=True,
    )
    assert renormalized.metadata["spacing_normalization_changes"] == {
        "measure_width_attributes_removed": 10,
        "note_default_x_attributes_removed": 10,
        "system_layout_elements_removed": 10,
        "staff_layout_elements_removed": 10,
    }


def test_multi_piece_segment_merge_exposes_homr_compare_candidate(
    tmp_path,
    monkeypatch,
) -> None:
    raw_paths = [tmp_path / "piece_1.pdf", tmp_path / "piece_2.pdf"]
    for raw_path in raw_paths:
        raw_path.write_bytes(_valid_pdf_bytes())

    def fake_generate(self, **kwargs):
        del self
        title = kwargs["title"]
        output_path = kwargs["output_path"]
        segment_index = 1 if "Troubadour" in title else 2
        output_path.write_text(
            _two_part_musicxml(title, segment_index + 1),
            encoding="utf-8",
        )
        homr_path = output_path.with_name(f"{output_path.stem}_homr.musicxml")
        homr_path.write_text(
            _two_part_musicxml(f"{title} HOMR", segment_index + 2),
            encoding="utf-8",
        )
        metadata = processing_engines_module._validate_musicxml(output_path)
        metadata["omr_attempts"] = [
            {
                "engine": "audiveris",
                "profile": "default",
                "candidate_path": str(output_path),
                "quality_score": 10.0 + segment_index,
            },
            {
                "engine": "homr",
                "profile": "experimental",
                "candidate_path": str(homr_path),
                "quality_score": 20.0 + segment_index,
            },
        ]
        return processing_engines_module.MusicXmlResult(
            file_path=output_path,
            engine_name="audiveris",
            engine_version="test",
            provenance="audiveris_omr",
            confidence=0.82,
            warnings=[],
            metadata=metadata,
        )

    monkeypatch.setattr(processing_engines_module.MusicXmlEngine, "generate", fake_generate)

    output_path = tmp_path / "candidate.musicxml"
    result = processing_engines_module.MusicXmlEngine().generate_multi_piece_segments(
        raw_pdf_paths=raw_paths,
        output_path=output_path,
        title="The Troubadour / Hoedown",
        composer="Rick Mooney",
        primary_instrument="Cello",
        contained_piece_titles=["The Troubadour", "Hoedown"],
        processing_settings={"allow_stub_musicxml": False},
    )

    attempts = result.metadata["omr_attempts"]
    assert len(attempts) == 1
    homr_attempt = attempts[0]
    assert homr_attempt["engine"] == "homr"
    assert homr_attempt["profile"] == "experimental_segment_merge"
    homr_merged_path = Path(homr_attempt["candidate_path"])
    assert homr_merged_path.exists()
    assert homr_merged_path.name == "candidate_homr_segment_merge.musicxml"
    homr_metadata = processing_engines_module._validate_musicxml(homr_merged_path)
    assert homr_metadata["measure_count"] == 7


def test_spacing_normalization_metadata_is_added_to_render_diagnostics() -> None:
    render_result = processing_engines_module.RenderResult(
        file_path=Path("candidate_review.pdf"),
        renderer_name="musescore",
        renderer_version="test",
        provenance="musescore_render",
        diagnostics={"exit_code": 0},
    )

    score_processing_module._attach_spacing_normalization_diagnostics(
        render_result,
        {
            "spacing_normalization_applied": True,
            "spacing_normalization_profile": "balanced_omr",
            "spacing_normalization_changes": {
                "measure_width_attributes_removed": 2,
                "note_default_x_attributes_removed": 4,
            },
        },
    )

    assert render_result.diagnostics["exit_code"] == 0
    assert render_result.diagnostics["spacing_normalization_applied"] is True
    assert render_result.diagnostics["spacing_normalization_profile"] == "balanced_omr"
    assert (
        render_result.diagnostics["spacing_normalization_changes"][
            "measure_width_attributes_removed"
        ]
        == 2
    )


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
    assert '<print new-system="yes" new-page="no" />' in musicxml
    assert (
        '<words default-x="500" font-weight="bold" font-size="16" '
        'halign="center" justify="center" valign="top">Hoedown</words>'
    ) in musicxml
    assert '<creator type="composer">Rick Mooney</creator>' in musicxml
    assert "Voice" not in musicxml
    assert 'part-name print-object="no"' in musicxml
    assert "<instrument-name>Cello</instrument-name>" in musicxml
    assert result.metadata["primary_instrument"] == "Cello"
    assert result.metadata["title"] == "The Troubadour / Hoedown"
    assert result.metadata["movement_title"] == "The Troubadour"


def test_homr_engine_collects_musicxml_output(tmp_path, monkeypatch) -> None:
    raw_image = tmp_path / "source.png"
    Image.new("RGB", (200, 120), "white").save(raw_image)
    output_path = tmp_path / "candidate.musicxml"
    fake_homr = tmp_path / "homr.exe"
    fake_homr.write_text("fake homr", encoding="utf-8")
    commands = []

    class FakeHomrStatus:
        discovered_path = str(fake_homr)
        version = "HOMR test"

    class FakeRunResult:
        returncode = 0
        stdout = "homr complete"
        stderr = ""

    def fake_homr_status(_settings):
        return FakeHomrStatus()

    def fake_run(command, **kwargs):
        commands.append((command, kwargs))
        output_dir = Path(kwargs["cwd"])
        (output_dir / "source.musicxml").write_text(
            processing_engines_module._build_stub_musicxml(
                title="HOMR Study",
                composer="Test Composer",
                primary_instrument="Cello",
                measure_count=2,
            ),
            encoding="utf-8",
        )
        return FakeRunResult()

    monkeypatch.setattr(processing_engines_module, "homr_status", fake_homr_status)
    monkeypatch.setattr(processing_engines_module.subprocess, "run", fake_run)

    result = processing_engines_module.HomrMusicXmlEngine().generate(
        raw_pdf_path=raw_image,
        output_path=output_path,
        title="HOMR Study",
        composer="Test Composer",
        primary_instrument="Cello",
        processing_settings={
            "homr_cli_path": str(fake_homr),
            "omr_strategy": "homr_experimental",
        },
    )

    assert result.engine_name == "homr"
    assert result.provenance == "homr_omr"
    assert output_path.exists()
    assert commands[0][0][0] == str(fake_homr)
    assert result.metadata["omr_strategy"] == "homr_experimental"
    assert result.metadata["omr_attempts"][0]["engine"] == "homr"


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


def test_reimporting_same_book_resumes_existing_children(api_client) -> None:
    client, _ = api_client
    book_bytes = _valid_pdf_bytes(page_count=2)
    source_hash = hashlib.sha256(book_bytes).hexdigest()
    split_hints = [
        {
            "title": "Resume Fanfare",
            "page_start": 1,
            "page_end": 1,
            "composer": "Debug Composer",
            "primary_instrument": "Cello",
            "confidence": 0.91,
        },
        {
            "title": "Resume Skating",
            "page_start": 2,
            "page_end": 2,
            "composer": "Debug Composer",
            "primary_instrument": "Cello",
            "confidence": 0.92,
        },
    ]

    def import_book():
        return client.post(
            "/api/v1/pieces/import",
            data={
                "title": "Resume Book",
                "composer": "Debug Composer",
                "catalog_mode": "book",
                "split_hints": json.dumps(split_hints),
            },
            files={
                "file": (
                    "resume_book.pdf",
                    book_bytes,
                    "application/pdf",
                )
            },
        )

    first_import = import_book()
    assert first_import.status_code == 200
    first_book = first_import.json()

    second_import = import_book()
    assert second_import.status_code == 200
    second_book = second_import.json()

    assert second_book["id"] == first_book["id"]
    assert second_book["source_content_sha256"] == source_hash
    assert second_book["attempt_status"] == "canonical"

    pieces = client.get("/api/v1/pieces/?include_attempts=true").json()
    matching_books = [
        piece
        for piece in pieces
        if piece["piece_kind"] == "book" and piece["source_content_sha256"] == source_hash
    ]
    assert [book["id"] for book in matching_books] == [first_book["id"]]

    children = [piece for piece in pieces if piece["source_book_id"] == first_book["id"]]
    assert sorted(piece["title"] for piece in children) == [
        "Resume Fanfare",
        "Resume Skating",
    ]
    assert all(piece["logical_piece_key"] for piece in children)

    jobs = client.get("/api/v1/jobs/").json()
    book_import_jobs = [
        job
        for job in jobs
        if job["piece_id"] == first_book["id"] and job["job_type"] == "book_import"
    ]
    assert len(book_import_jobs) == 1

    split_reviews = [
        item
        for item in client.get("/api/v1/review/").json()
        if item["candidate_data"].get("source_book_id") == first_book["id"]
        and item["candidate_data"].get("processing_stage") == "split_review_needed"
    ]
    assert len(split_reviews) == 2


def test_reimporting_same_standalone_pdf_reuses_existing_piece(api_client) -> None:
    client, _ = api_client
    pdf_bytes = _valid_pdf_bytes()
    source_hash = hashlib.sha256(pdf_bytes).hexdigest()

    def import_piece():
        return client.post(
            "/api/v1/pieces/import",
            data={"title": "Standalone Duplicate Guard"},
            files={
                "file": (
                    "standalone_duplicate_guard.pdf",
                    pdf_bytes,
                    "application/pdf",
                )
            },
        )

    first_import = import_piece()
    assert first_import.status_code == 200
    second_import = import_piece()
    assert second_import.status_code == 200

    first_piece = first_import.json()
    second_piece = second_import.json()
    assert second_piece["id"] == first_piece["id"]

    pieces = client.get("/api/v1/pieces/?include_attempts=true").json()
    matching_pieces = [
        piece
        for piece in pieces
        if piece["piece_kind"] == "piece" and piece["source_content_sha256"] == source_hash
    ]
    assert [piece["id"] for piece in matching_pieces] == [first_piece["id"]]


def test_debug_duplicate_cleanup_archives_attempts_without_deleting_access(api_client) -> None:
    client, _ = api_client
    created = []
    for suffix in ("a", "b"):
        piece = client.post(
            "/api/v1/pieces/",
            json={
                "title": "Duplicate Jig",
                "composer": "Debug Composer",
                "file_name": f"duplicate_jig_{suffix}.pdf",
            },
        ).json()
        patch = client.patch(
            f"/api/v1/pieces/{piece['id']}",
            json={
                "primary_instrument": "Cello",
                "book_or_collection": "Position Pieces for Cello, Book 1",
                "source_page_start": 46,
                "source_page_end": 46,
                "catalog_metadata": {
                    "title": "Duplicate Jig",
                    "composer": "Debug Composer",
                    "primary_instrument": "Cello",
                    "book_or_collection": "Position Pieces for Cello, Book 1",
                    "source_page_start": 46,
                    "source_page_end": 46,
                },
            },
        )
        assert patch.status_code == 200
        review = client.post(
            "/api/v1/review/",
            json={
                "piece_id": piece["id"],
                "item_type": "score_candidate",
                "title": "Review book split for Duplicate Jig",
                "candidate_data": {
                    "piece_title": "Duplicate Jig",
                    "source_book_id": "legacy-position-pieces",
                    "source_page_start": 46,
                    "source_page_end": 46,
                    "processing_stage": "split_review_needed",
                    "catalog_metadata": {
                        "title": "Duplicate Jig",
                        "composer": "Debug Composer",
                        "primary_instrument": "Cello",
                        "book_or_collection": "Position Pieces for Cello, Book 1",
                        "source_page_start": 46,
                        "source_page_end": 46,
                    },
                },
            },
        )
        assert review.status_code == 200
        created.append(piece["id"])

    duplicate_report = client.get("/api/v1/debug/duplicates").json()
    assert duplicate_report["duplicate_group_count"] == 1
    assert duplicate_report["duplicate_piece_count"] == 1

    cleanup = client.post("/api/v1/debug/duplicates/cleanup")
    assert cleanup.status_code == 200
    cleanup_payload = cleanup.json()
    assert cleanup_payload["archived_piece_count"] == 1
    assert cleanup_payload["superseded_review_item_count"] == 1

    visible_piece_ids = {piece["id"] for piece in client.get("/api/v1/pieces/").json()}
    assert len(visible_piece_ids & set(created)) == 1

    all_piece_ids = {
        piece["id"] for piece in client.get("/api/v1/pieces/?include_attempts=true").json()
    }
    assert set(created).issubset(all_piece_ids)

    review_queue_piece_ids = {item["piece_id"] for item in client.get("/api/v1/review/").json()}
    assert len(review_queue_piece_ids & set(created)) == 1


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
    assert candidate_review["candidate_data"]["source_book_id"] == book_id

    summary = client.get("/api/v1/jobs/summary").json()
    assert summary["queued_count"] == 0
    assert summary["running_count"] == 0
    assert summary["succeeded_count"] >= 1


def test_async_dispatcher_honors_configured_concurrency_limit(
    api_client,
    monkeypatch,
) -> None:
    client, _ = api_client
    settings_response = client.patch(
        "/api/v1/processing/settings",
        json={"max_concurrent_jobs": 2},
    )
    assert settings_response.status_code == 200
    for index in range(3):
        piece_response = client.post(
            "/api/v1/pieces/",
            json={
                "title": f"Concurrent Piece {index + 1}",
                "file_name": f"concurrent_piece_{index + 1}.pdf",
            },
        )
        assert piece_response.status_code == 200
        job_response = client.post(
            "/api/v1/jobs/trigger",
            json={
                "job_type": "score_processing",
                "piece_id": piece_response.json()["id"],
            },
        )
        assert job_response.status_code == 200

    async def exercise_dispatcher() -> list[str]:
        started_job_ids: list[str] = []
        release = asyncio.Event()

        async def fake_process_claimed_job(self, job_id: str) -> None:
            started_job_ids.append(job_id)
            await release.wait()

        monkeypatch.setattr(
            JobDispatcher,
            "_process_claimed_job",
            fake_process_claimed_job,
        )
        dispatcher = JobDispatcher(poll_interval_seconds=0, stale_after_seconds=1)
        try:
            assert await dispatcher.start_available_jobs() == 2
            await asyncio.sleep(0)
            assert len(started_job_ids) == 2
            assert len(dispatcher._running_tasks) == 2
            return started_job_ids
        finally:
            release.set()
            if dispatcher._running_tasks:
                await asyncio.gather(
                    *dispatcher._running_tasks,
                    return_exceptions=True,
                )

    started_job_ids = asyncio.run(exercise_dispatcher())
    assert len(started_job_ids) == 2

    jobs = client.get("/api/v1/jobs/").json()
    assert sum(1 for job in jobs if job["status"] == "running") == 2
    assert sum(1 for job in jobs if job["status"] == "queued") == 1


def test_bulk_approve_book_split_reviews_is_scoped_to_source_book(api_client) -> None:
    client, _ = api_client
    book = client.post(
        "/api/v1/pieces/",
        json={"title": "Bulk Book", "file_name": "bulk_book.pdf"},
    ).json()
    child_one = client.post(
        "/api/v1/pieces/",
        json={"title": "Bulk One", "file_name": "bulk_one.pdf"},
    ).json()
    child_two = client.post(
        "/api/v1/pieces/",
        json={"title": "Bulk Two", "file_name": "bulk_two.pdf"},
    ).json()
    unrelated = client.post(
        "/api/v1/pieces/",
        json={"title": "Other Book Piece", "file_name": "other.pdf"},
    ).json()

    def create_split_review(piece_id: str, source_book_id: str, title: str) -> str:
        response = client.post(
            "/api/v1/review/",
            json={
                "piece_id": piece_id,
                "item_type": "score_candidate",
                "title": f"Review book split for {title}",
                "candidate_data": {
                    "piece_title": title,
                    "source_book_id": source_book_id,
                    "processing_stage": "split_review_needed",
                    "catalog_metadata": {"title": title},
                },
            },
        )
        assert response.status_code == 200
        return response.json()["id"]

    skipped_item_id = create_split_review(child_one["id"], book["id"], "Bulk One")
    approved_item_id = create_split_review(child_two["id"], book["id"], "Bulk Two")
    unrelated_item_id = create_split_review(unrelated["id"], "other-book", "Other Book Piece")

    assert (
        client.post(f"/api/v1/review/{skipped_item_id}", json={"action": "approve"}).status_code
        == 200
    )

    bulk_response = client.post(
        "/api/v1/review/bulk/approve",
        json={
            "source_book_id": book["id"],
            "processing_stage": "split_review_needed",
        },
    )

    assert bulk_response.status_code == 200
    bulk = bulk_response.json()
    assert bulk["approved_count"] == 1
    assert bulk["skipped_count"] == 1
    assert bulk["failed_count"] == 0
    assert bulk["approved_item_ids"] == [approved_item_id]
    assert bulk["skipped_item_ids"] == [skipped_item_id]

    review_items = {
        item["id"]: item for item in client.get("/api/v1/review/?include_resolved=true").json()
    }
    assert review_items[approved_item_id]["status"] == "approved"
    assert review_items[skipped_item_id]["status"] == "approved"
    assert review_items[unrelated_item_id]["status"] == "pending"


def test_bulk_approve_book_candidate_reviews_marks_pieces_ready(api_client) -> None:
    client, _ = api_client
    book = client.post(
        "/api/v1/pieces/",
        json={"title": "Bulk Candidate Book", "file_name": "bulk_candidate_book.pdf"},
    ).json()
    source_review = client.post(
        "/api/v1/review/",
        json={
            "piece_id": book["id"],
            "item_type": "score_candidate",
            "title": "Original split review",
            "candidate_data": {
                "piece_title": book["title"],
                "source_book_id": book["id"],
                "processing_stage": "split_review_needed",
            },
        },
    ).json()
    children = [
        client.post(
            "/api/v1/pieces/",
            json={"title": title, "file_name": f"{title.lower().replace(' ', '_')}.pdf"},
        ).json()
        for title in ("Candidate One", "Candidate Two")
    ]

    for child in children:
        response = client.post(
            "/api/v1/review/",
            json={
                "piece_id": child["id"],
                "item_type": "score_candidate",
                "title": f"Review reconstructed score for {child['title']}",
                "candidate_data": {
                    "piece_title": child["title"],
                    "source_review_item_id": source_review["id"],
                    "processing_stage": "candidate_review_needed",
                    "catalog_metadata": {"title": child["title"]},
                },
            },
        )
        assert response.status_code == 200

    bulk_response = client.post(
        "/api/v1/review/bulk/approve",
        json={
            "source_review_item_id": source_review["id"],
            "processing_stage": "candidate_review_needed",
        },
    )

    assert bulk_response.status_code == 200
    assert bulk_response.json()["approved_count"] == 2
    pieces = {piece["id"]: piece for piece in client.get("/api/v1/pieces/").json()}
    assert pieces[children[0]["id"]]["status"] == "approved"
    assert pieces[children[0]["id"]]["library_status"] == "ready"
    assert pieces[children[1]["id"]]["status"] == "approved"
    assert pieces[children[1]["id"]]["library_status"] == "ready"


def test_score_candidate_approval_keeps_authoritative_catalog_metadata(api_client) -> None:
    client, _ = api_client
    piece = client.post(
        "/api/v1/pieces/",
        json={"title": "Landler", "composer": "Rick Mooney", "file_name": "landler.pdf"},
    ).json()
    update_response = client.patch(
        f"/api/v1/pieces/{piece['id']}",
        json={
            "title": "Landler",
            "composer": "Rick Mooney",
            "primary_instrument": "Cello",
            "book_or_collection": "Position Pieces for Cello, Book 1",
            "source_page_start": 57,
            "source_page_end": 57,
            "catalog_metadata": {
                "title": "Landler",
                "composer": "Rick Mooney",
                "primary_instrument": "Cello",
                "book_or_collection": "Position Pieces for Cello, Book 1",
                "source_page_start": 57,
                "source_page_end": 57,
            },
        },
    )
    assert update_response.status_code == 200

    review = client.post(
        "/api/v1/review/",
        json={
            "piece_id": piece["id"],
            "item_type": "score_candidate",
            "title": "Review reconstructed score for Landler",
            "candidate_data": {
                "piece_title": "Landler",
                "processing_stage": "candidate_review_needed",
                "catalog_suggestions": [
                    {
                        "source": "ocr_text",
                        "confidence": 0.78,
                        "fields": {
                            "title": "Landler",
                            "composer": "OOo Ee",
                            "catalog_number": "D.C. al Fine",
                            "publisher": "a ©. ~~ 4 Vv",
                        },
                    }
                ],
            },
        },
    )
    assert review.status_code == 200

    approval = client.post(
        f"/api/v1/review/{review.json()['id']}",
        json={"action": "approve"},
    )
    assert approval.status_code == 200

    detail = client.get(f"/api/v1/pieces/{piece['id']}").json()
    assert detail["composer"] == "Rick Mooney"
    assert detail["catalog_metadata"]["composer"] == "Rick Mooney"
    assert detail["catalog_metadata"]["primary_instrument"] == "Cello"
    assert detail["catalog_metadata"]["book_or_collection"] == "Position Pieces for Cello, Book 1"
    assert detail["catalog_metadata"].get("catalog_number") != "D.C. al Fine"
    assert detail["catalog_metadata"].get("publisher") != "a ©. ~~ 4 Vv"


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


def test_cancel_queued_job_prevents_dispatch_and_updates_summary(api_client) -> None:
    client, _ = api_client
    job_response = client.post(
        "/api/v1/jobs/trigger",
        json={"job_type": "score_processing", "piece_id": "missing-piece"},
    )
    assert job_response.status_code == 200
    job_id = job_response.json()["id"]

    cancel_response = client.post(f"/api/v1/jobs/{job_id}/cancel")
    assert cancel_response.status_code == 200
    canceled = cancel_response.json()
    assert canceled["status"] == "canceled"
    assert canceled["progress"] == 100.0
    assert canceled["error_message"] == "Canceled by parent debug tools."

    dispatcher = JobDispatcher(poll_interval_seconds=0, stale_after_seconds=1)
    assert asyncio.run(dispatcher.run_once()) is False

    summary = client.get("/api/v1/jobs/summary").json()
    assert summary["queued_count"] == 0
    assert summary["running_count"] == 0
    assert summary["canceled_count"] == 1


def test_cancel_completed_job_is_idempotent(api_client) -> None:
    client, _ = api_client
    job = client.post(
        "/api/v1/jobs/trigger",
        json={"job_type": "score_processing"},
    ).json()
    update_response = client.patch(
        f"/api/v1/jobs/{job['id']}",
        json={"status": "succeeded", "progress": 100.0},
    )
    assert update_response.status_code == 200

    cancel_response = client.post(f"/api/v1/jobs/{job['id']}/cancel")
    assert cancel_response.status_code == 200
    assert cancel_response.json()["status"] == "succeeded"


def test_job_list_includes_linked_piece_display_fields(api_client) -> None:
    client, _ = api_client
    piece_response = client.post(
        "/api/v1/pieces/",
        json={
            "title": "Landler",
            "composer": "Rick Mooney",
            "file_name": "landler.pdf",
        },
    )
    assert piece_response.status_code == 200
    piece = piece_response.json()

    job_response = client.post(
        "/api/v1/jobs/trigger",
        json={"job_type": "score_processing", "piece_id": piece["id"]},
    )
    assert job_response.status_code == 200
    job = job_response.json()
    assert job["piece_title"] == "Landler"
    assert job["piece_composer"] == "Rick Mooney"
    assert job["piece_status"] == "imported"

    listed_job = next(
        item for item in client.get("/api/v1/jobs/").json() if item["id"] == job["id"]
    )
    assert listed_job["piece_title"] == "Landler"
    assert listed_job["piece_composer"] == "Rick Mooney"
    assert listed_job["piece_status"] == "imported"


def test_retry_failed_score_processing_job_requeues_same_piece(api_client) -> None:
    client, _ = api_client
    piece_response = client.post(
        "/api/v1/pieces/",
        json={
            "title": "Retry Etude",
            "composer": "Debug Composer",
            "file_name": "retry_etude.pdf",
        },
    )
    assert piece_response.status_code == 200
    piece = piece_response.json()

    job = client.post(
        "/api/v1/jobs/trigger",
        json={"job_type": "score_processing", "piece_id": piece["id"]},
    ).json()
    failed_response = client.patch(
        f"/api/v1/jobs/{job['id']}",
        json={
            "status": "failed",
            "progress": 100,
            "error_message": "MuseScore Studio failed without returning diagnostic output.",
            "result_data": {"retry_count": 2, "last_error": "MuseScore failed"},
        },
    )
    assert failed_response.status_code == 200

    retry_response = client.post(f"/api/v1/jobs/{job['id']}/retry")
    assert retry_response.status_code == 200
    retried = retry_response.json()
    assert retried["status"] == "queued"
    assert retried["progress"] == 0
    assert retried["error_message"] is None
    assert retried["piece_title"] == "Retry Etude"
    assert retried["result_data"]["retry_count"] == 0
    assert retried["result_data"]["manual_retry_count"] == 1
    assert retried["result_data"]["previous_retry_error"] == (
        "MuseScore Studio failed without returning diagnostic output."
    )
    assert "last_manual_retry_at" in retried["result_data"]
    assert "last_error" not in retried["result_data"]


def test_retry_rejects_non_failed_or_non_score_jobs(api_client) -> None:
    client, _ = api_client
    queued_job = client.post(
        "/api/v1/jobs/trigger",
        json={"job_type": "score_processing"},
    ).json()
    queued_retry = client.post(f"/api/v1/jobs/{queued_job['id']}/retry")
    assert queued_retry.status_code == 409

    other_job = client.post(
        "/api/v1/jobs/trigger",
        json={"job_type": "book_import"},
    ).json()
    failed_other = client.patch(
        f"/api/v1/jobs/{other_job['id']}",
        json={"status": "failed", "progress": 100},
    )
    assert failed_other.status_code == 200
    other_retry = client.post(f"/api/v1/jobs/{other_job['id']}/retry")
    assert other_retry.status_code == 409


def test_debug_clear_workflow_preserves_settings_and_clears_generated_data(
    api_client,
) -> None:
    client, storage_path = api_client
    settings_file = storage_path / "processing_settings.json"
    settings_file.parent.mkdir(parents=True, exist_ok=True)
    settings_file.write_text('{"musescore_cli_path":"C:/MuseScore/MuseScore4.exe"}')
    generated_piece = storage_path / "pieces" / "piece-1" / "candidate.pdf"
    generated_state = storage_path / "piece_state" / "piece-1.json"
    generated_piece.parent.mkdir(parents=True, exist_ok=True)
    generated_state.parent.mkdir(parents=True, exist_ok=True)
    generated_piece.write_bytes(b"pdf")
    generated_state.write_text("{}")

    import_response = client.post(
        "/api/v1/pieces/import",
        data={"title": "Debug Clear Piece"},
        files={
            "file": (
                "debug_clear.pdf",
                _valid_pdf_bytes(page_count=1),
                "application/pdf",
            )
        },
    )
    assert import_response.status_code == 200
    assert client.get("/api/v1/pieces/").json()
    assert client.get("/api/v1/jobs/").json()
    preserved_settings = settings_file.read_text()

    clear_response = client.post("/api/v1/debug/clear-workflow")
    assert clear_response.status_code == 200
    payload = clear_response.json()
    assert payload["status"] == "cleared"
    assert "backup_dir" in payload

    assert client.get("/api/v1/pieces/").json() == []
    assert client.get("/api/v1/review/").json() == []
    assert client.get("/api/v1/jobs/").json() == []
    assert settings_file.read_text() == preserved_settings
    assert not generated_piece.exists()
    assert not generated_state.exists()


def test_multi_piece_review_warns_when_rendered_staff_lines_drop(monkeypatch, tmp_path) -> None:
    raw_pdf = tmp_path / "raw.pdf"
    rendered_pdf = tmp_path / "rendered.pdf"
    raw_pdf.write_bytes(b"%PDF raw")
    rendered_pdf.write_bytes(b"%PDF rendered")

    def fake_line_count(path):
        return 44 if path == raw_pdf else 32

    monkeypatch.setattr(score_processing_module, "_pdf_horizontal_line_count", fake_line_count)

    warnings = score_processing_module._score_candidate_review_warnings(
        raw_pdf_path=raw_pdf,
        raw_page_count=1,
        render_result=processing_engines_module.RenderResult(
            file_path=rendered_pdf,
            renderer_name="musescore",
            renderer_version="test",
            provenance="musescore_render",
            validation_status="valid",
            validation_error=None,
            file_size_bytes=1000,
            page_count=1,
        ),
        musicxml_provenance="audiveris_omr",
        contained_piece_titles=["The Troubadour", "Hoedown"],
        multi_piece_page=True,
    )

    assert any("fewer detected staff-line groups" in warning for warning in warnings)


def test_multi_piece_review_pdf_title_overlay_centers_second_title(tmp_path) -> None:
    rendered_pdf = tmp_path / "rendered.pdf"
    rendered_pdf.write_bytes(_valid_pdf_bytes())
    render_result = processing_engines_module.RenderResult(
        file_path=rendered_pdf,
        renderer_name="musescore",
        renderer_version="test",
        provenance="musescore_render",
        validation_status="valid",
        validation_error=None,
        file_size_bytes=rendered_pdf.stat().st_size,
        page_count=1,
    )

    score_processing_module._repair_multi_piece_review_pdf_titles(
        render_result,
        contained_piece_titles=["The Troubadour", "Hoedown"],
        multi_piece_page=True,
    )

    assert render_result.validation_status == "valid"
    assert render_result.page_count == 1
    assert render_result.diagnostics["multi_piece_title_overlay_applied"] is True
    assert render_result.diagnostics["multi_piece_title_overlay_titles"] == ["Hoedown"]
    text = PdfReader(str(rendered_pdf)).pages[0].extract_text()
    assert "Hoedown" in text


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


def test_rejected_review_keeps_original_pushable(api_client) -> None:
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
    assert piece_detail["status"] == "needs_edits"
    assert piece_detail["library_status"] == "needsEdits"
    assert any(
        version["score_version_role"] == "original_pdf"
        for version in piece_detail["score_versions"]
    )
    assert any(
        version["score_version_role"] == "canonical_musicxml"
        and version["version_type"] == "rejected"
        for version in piece_detail["score_versions"]
    )

    push_response = client.post(
        f"/api/v1/pieces/{piece_id}/push",
        json={"profile_ids": ["student-alyse"]},
    )
    assert push_response.status_code == 409

    original_push_response = client.post(
        f"/api/v1/pieces/{piece_id}/push",
        json={"profile_ids": ["student-alyse"], "mode": "original_pdf"},
    )
    assert original_push_response.status_code == 200
    pushed_piece = original_push_response.json()
    assert pushed_piece["status"] == "needs_edits"
    assert pushed_piece["visible_to_profile_ids"] == ["student-alyse"]

    assigned_response = client.get("/api/v1/pieces/assigned/student-alyse")
    assert assigned_response.status_code == 200
    assigned_ids = [piece["id"] for piece in assigned_response.json()]
    assert piece_id in assigned_ids


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
    assert settings_payload["max_concurrent_jobs"] == 2
    assert settings_payload["ocr_language"] == "eng"
    assert "homr_cli_path" in settings_payload

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
    assert validation["homr"]["name"] == "HOMR"

    missing_homr_response = client.post(
        "/api/v1/processing/settings/validate",
        json={
            "homr_cli_path": str(storage_path / "missing-homr.exe"),
            "omr_strategy": "homr_experimental",
        },
    )
    assert missing_homr_response.status_code == 200
    missing_homr = missing_homr_response.json()
    assert missing_homr["valid"] is False
    assert missing_homr["homr"]["available"] is False
    assert any("HOMR" in warning for warning in missing_homr["warnings"])

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
            "max_concurrent_jobs": 4,
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
    assert updated["max_concurrent_jobs"] == 4

    invalid_concurrency_response = client.patch(
        "/api/v1/processing/settings",
        json={"max_concurrent_jobs": 5},
    )
    assert invalid_concurrency_response.status_code == 422

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


def test_processing_settings_auto_discovers_standard_windows_tool_paths(
    tmp_path, monkeypatch
) -> None:
    program_files = tmp_path / "Program Files"
    audiveris = program_files / "Audiveris" / "Audiveris.exe"
    musescore = program_files / "MuseScore 4" / "bin" / "MuseScore4.exe"
    tesseract = program_files / "Tesseract-OCR" / "tesseract.exe"
    for executable in (audiveris, musescore, tesseract):
        executable.parent.mkdir(parents=True, exist_ok=True)
        executable.write_text("fake executable", encoding="utf-8")

    monkeypatch.setenv("ProgramFiles", str(program_files))
    monkeypatch.delenv("ProgramFiles(x86)", raising=False)
    monkeypatch.setattr(processing_settings_module.settings, "audiveris_cli_path", None)
    monkeypatch.setattr(processing_settings_module.settings, "musescore_cli_path", None)
    monkeypatch.setattr(processing_settings_module.settings, "ocr_cli_path", None)

    store = processing_settings_module.ProcessingSettingsStore(
        settings_path=tmp_path / "processing_settings.json"
    )
    settings_payload = store.load_response().model_dump()
    validation = store.validate()

    assert settings_payload["audiveris_cli_path"] == str(audiveris)
    assert settings_payload["musescore_cli_path"] == str(musescore)
    assert settings_payload["ocr_cli_path"] == str(tesseract)
    assert validation.audiveris.available is True
    assert validation.musescore.available is True
    assert validation.ocr.available is True
    assert not any("Audiveris is not configured" in item for item in validation.warnings)
    assert not any("MuseScore is not configured" in item for item in validation.warnings)
    assert not any("Tesseract OCR is not configured" in item for item in validation.warnings)

    stale_settings_path = tmp_path / "stale_processing_settings.json"
    stale_settings_path.write_text(
        json.dumps(
            {
                "audiveris_cli_path": str(tmp_path / "old" / "Audiveris.exe"),
                "musescore_cli_path": str(tmp_path / "old" / "MuseScore4.exe"),
                "ocr_cli_path": str(tmp_path / "old" / "tesseract.exe"),
            }
        ),
        encoding="utf-8",
    )
    stale_store = processing_settings_module.ProcessingSettingsStore(
        settings_path=stale_settings_path
    )
    stale_payload = stale_store.load_response().model_dump()
    stale_validation = stale_store.validate()

    assert stale_payload["audiveris_cli_path"] == str(audiveris)
    assert stale_payload["musescore_cli_path"] == str(musescore)
    assert stale_payload["ocr_cli_path"] == str(tesseract)
    assert stale_validation.audiveris.available is True
    assert stale_validation.musescore.available is True
    assert stale_validation.ocr.available is True


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

    setup_response = client.get("http://localhost:8795/setup")
    assert setup_response.status_code == 200
    assert "Pair an AZMusic device" in setup_response.text
    assert "azmusic://pair?" in setup_response.text
    assert "parent_setup" in setup_response.text
    assert "/api/v1/pairing/code.png?code=" in setup_response.text


def test_local_setup_page_pairs_with_detected_lan_url(api_client, monkeypatch) -> None:
    client, _ = api_client
    monkeypatch.setattr(
        server_urls_module,
        "detect_lan_ipv4_candidates",
        lambda: ["192.168.50.25", "10.0.0.8"],
    )

    setup_response = client.get("http://localhost:8795/setup")

    assert setup_response.status_code == 200
    assert "server_url=http%3A%2F%2F192.168.50.25%3A8795" in setup_response.text
    assert "alt_server_url=http%3A%2F%2F10.0.0.8%3A8795" in setup_response.text
    assert "Alternate URLs if pairing times out" in setup_response.text
    assert "Opened from:" in setup_response.text


def test_detected_server_urls_prefer_lan_over_windows_sandbox_addresses() -> None:
    addresses = server_urls_module._select_reachable_ipv4_candidates(
        ["172.31.2.102", "192.168.50.25", "10.0.0.8"]
    )

    assert [str(address) for address in addresses] == [
        "192.168.50.25",
        "10.0.0.8",
        "172.31.2.102",
    ]


def test_public_server_url_overrides_pairing_payload(api_client, monkeypatch) -> None:
    client, _ = api_client
    monkeypatch.setattr(settings, "public_server_url", "http://music-server.local:8795/")

    code_response = client.get("/api/v1/pairing/code")

    assert code_response.status_code == 200
    code_payload = code_response.json()
    assert code_payload["server_url"] == "http://music-server.local:8795"
    assert code_payload["alternate_server_urls"] == []
    assert "server_url=http%3A%2F%2Fmusic-server.local%3A8795" in code_payload["pairing_uri"]


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


def test_protected_processing_settings_require_parent_pairing_token(
    api_client,
    monkeypatch,
) -> None:
    client, _ = api_client
    monkeypatch.setattr(settings, "require_device_auth", True)

    unpaired_response = client.get("/api/v1/processing/settings")
    assert unpaired_response.status_code == 401

    code_response = client.get(
        "/api/v1/pairing/code",
        params={
            "purpose": "parent_setup",
            "profile_id": "parent-main",
            "profile_name": "Parent",
            "role": "parent",
        },
    )
    assert code_response.status_code == 200
    claim_response = client.post(
        "/api/v1/pairing/claim",
        json={
            "pairing_code": code_response.json()["pairing_code"],
            "device_id": "parent-surface",
            "device_name": "Parent Surface",
            "platform": "windows",
        },
    )
    assert claim_response.status_code == 200
    token = claim_response.json()["device_token"]
    auth_headers = {"X-AZMusic-Device-Token": token}

    settings_response = client.get(
        "/api/v1/processing/settings",
        headers=auth_headers,
    )
    assert settings_response.status_code == 200
    assert settings_response.json()["processing_mode"] == "server_only"

    validation_response = client.post(
        "/api/v1/processing/settings/validate",
        json={},
        headers=auth_headers,
    )
    assert validation_response.status_code == 200

    capabilities_response = client.get(
        "/api/v1/processing/capabilities",
        headers=auth_headers,
    )
    assert capabilities_response.status_code == 200

    update_response = client.patch(
        "/api/v1/processing/settings",
        json={"processing_mode": "server_plus_device_workers"},
        headers=auth_headers,
    )
    assert update_response.status_code == 200
    assert update_response.json()["processing_mode"] == "server_plus_device_workers"


def test_release_install_pair_import_review_push_smoke_loop(
    api_client,
    monkeypatch,
) -> None:
    client, _ = api_client
    monkeypatch.setattr(settings, "require_device_auth", True)

    parent_code_response = client.get(
        "/api/v1/pairing/code",
        params={
            "purpose": "parent_setup",
            "profile_id": "parent-main",
            "profile_name": "Parent",
            "role": "parent",
        },
    )
    assert parent_code_response.status_code == 200
    parent_claim_response = client.post(
        "/api/v1/pairing/claim",
        json={
            "pairing_code": parent_code_response.json()["pairing_code"],
            "device_id": "parent-installer-smoke",
            "device_name": "Parent Installer Smoke",
            "platform": "windows",
        },
    )
    assert parent_claim_response.status_code == 200
    parent_headers = {"X-AZMusic-Device-Token": parent_claim_response.json()["device_token"]}

    assert (
        client.get(
            "/api/v1/processing/settings",
            headers=parent_headers,
        ).status_code
        == 200
    )

    student_profile_id = "student-kai"
    student_code_response = client.get(
        "/api/v1/pairing/code",
        params={
            "purpose": "student_device",
            "profile_id": student_profile_id,
            "profile_name": "Kai",
            "role": "student",
        },
    )
    assert student_code_response.status_code == 200
    student_claim_response = client.post(
        "/api/v1/pairing/claim",
        json={
            "pairing_code": student_code_response.json()["pairing_code"],
            "device_id": "kai-android-smoke",
            "device_name": "Kai Android Smoke",
            "platform": "android",
        },
    )
    assert student_claim_response.status_code == 200
    student_headers = {"X-AZMusic-Device-Token": student_claim_response.json()["device_token"]}

    import_response = client.post(
        "/api/v1/pieces/import",
        data={
            "title": "Smoke Etude",
            "composer": "AZMusic",
            "primary_instrument": "Cello",
        },
        files={
            "file": (
                "smoke_etude.pdf",
                b"%PDF-1.4\n%AZMusic release smoke pdf\n",
                "application/pdf",
            )
        },
        headers=parent_headers,
    )
    assert import_response.status_code == 200
    piece_id = import_response.json()["id"]

    jobs_response = client.get("/api/v1/jobs/", headers=parent_headers)
    assert jobs_response.status_code == 200
    job = next(job for job in jobs_response.json() if job["piece_id"] == piece_id)
    assert job["status"] == "succeeded"

    review_response = client.get("/api/v1/review/", headers=parent_headers)
    assert review_response.status_code == 200
    review_item = next(item for item in review_response.json() if item["piece_id"] == piece_id)
    assert review_item["item_type"] == "score_candidate"

    approve_response = client.post(
        f"/api/v1/review/{review_item['id']}",
        json={"action": "approve"},
        headers=parent_headers,
    )
    assert approve_response.status_code == 200

    push_response = client.post(
        f"/api/v1/pieces/{piece_id}/push",
        json={"profile_ids": [student_profile_id]},
        headers=parent_headers,
    )
    assert push_response.status_code == 200
    assert push_response.json()["visible_to_profile_ids"] == [student_profile_id]

    assigned_response = client.get(
        f"/api/v1/pieces/assigned/{student_profile_id}",
        headers=student_headers,
    )
    assert assigned_response.status_code == 200
    assigned_piece = next(item for item in assigned_response.json() if item["id"] == piece_id)
    assert assigned_piece["library_status"] == "ready"
    assert assigned_piece["primary_instrument"] == "Cello"


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
