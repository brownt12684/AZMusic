"""Integration tests for AZMusic server routers (pieces, jobs, sync, review)."""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

from main import app
from database import get_db, Base
from models.orm import Piece, PieceStatus, ReviewItem, ReviewAction, Job, JobStatus, SyncState
from config import get_settings

# ---------------------------------------------------------------------------
# Test database setup — use SQLite in-memory for isolation
# ---------------------------------------------------------------------------

SQLITE_URL = "sqlite:///file::memory:?cache=shared"

engine = create_engine(
    SQLITE_URL,
    connect_args={"check_same_thread": False},
)

TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def _override_get_db():
    """Yield a fresh test session; tables are created once."""
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = _override_get_db

client = TestClient(app)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _create_piece(db, title: str = "Etude", status: PieceStatus = PieceStatus.draft) -> Piece:
    piece = Piece(title=title, status=status)
    db.add(piece)
    db.commit()
    db.refresh(piece)
    return piece


# ===========================================================================
# Pieces Router
# ===========================================================================


class TestPieces:
    """CRUD + media + history-drafts for pieces router."""

    # -- list --
    def test_list_pieces_empty(self):
        resp = client.get("/api/v1/pieces/")
        assert resp.status_code == 200
        assert resp.json() == []

    # -- create --
    def test_create_piece(self):
        resp = client.post("/api/v1/pieces/", json={"title": "Bowings 1"})
        assert resp.status_code == 200
        data = resp.json()
        assert data["title"] == "Bowings 1"
        assert data["status"] == PieceStatus.draft

    def test_create_piece_missing_title(self):
        resp = client.post("/api/v1/pieces/", json={})
        assert resp.status_code == 422

    # -- get by id --
    def test_get_piece(self):
        with TestingSessionLocal() as db:
            piece = _create_piece(db, "Scales")
            pid = piece.id

        resp = client.get(f"/api/v1/pieces/{pid}")
        assert resp.status_code == 200
        assert resp.json()["title"] == "Scales"

    def test_get_piece_not_found(self):
        resp = client.get("/api/v1/pieces/99999")
        assert resp.status_code == 404

    # -- update --
    def test_update_piece(self):
        with TestingSessionLocal() as db:
            piece = _create_piece(db, "Arpeggios")
            pid = piece.id

        resp = client.patch(f"/api/v1/pieces/{pid}", json={"title": "Arpeggios Revised"})
        assert resp.status_code == 200
        assert resp.json()["title"] == "Arpeggios Revised"

    def test_update_piece_status(self):
        with TestingSessionLocal() as db:
            piece = _create_piece(db, "Concerto", status=PieceStatus.draft)
            pid = piece.id

        resp = client.patch(f"/api/v1/pieces/{pid}", json={"status": PieceStatus.practicing})
        assert resp.status_code == 200
        assert resp.json()["status"] == PieceStatus.practicing

    def test_update_piece_not_found(self):
        resp = client.patch("/api/v1/pieces/99999", json={"title": "x"})
        assert resp.status_code == 404

    # -- delete --
    def test_delete_piece(self):
        with TestingSessionLocal() as db:
            piece = _create_piece(db, "To Delete")
            pid = piece.id

        resp = client.delete(f"/api/v1/pieces/{pid}")
        assert resp.status_code == 200

        resp = client.get(f"/api/v1/pieces/{pid}")
        assert resp.status_code == 404

    def test_delete_piece_not_found(self):
        resp = client.delete("/api/v1/pieces/99999")
        assert resp.status_code == 404

    # -- media upload --
    def test_upload_media_valid(self):
        with TestingSessionLocal() as db:
            piece = _create_piece(db, "Media Test")
            pid = piece.id

        resp = client.post(
            f"/api/v1/pieces/{pid}/media",
            files={"file": ("scan.pdf", b"fake pdf", "application/pdf")},
            data={"asset_type": "scan"},
        )
        assert resp.status_code == 200

    @pytest.mark.parametrize("asset_type", ["image", "scan", "audio"])
    def test_upload_media_all_types(self, asset_type):
        with TestingSessionLocal() as db:
            piece = _create_piece(db, f"Media {asset_type}")
            pid = piece.id

        resp = client.post(
            f"/api/v1/pieces/{pid}/media",
            files={"file": ("x.pdf", b"data", "application/pdf")},
            data={"asset_type": asset_type},
        )
        assert resp.status_code == 200

    def test_upload_media_invalid_type(self):
        with TestingSessionLocal() as db:
            piece = _create_piece(db, "Bad Type")
            pid = piece.id

        resp = client.post(
            f"/api/v1/pieces/{pid}/media",
            files={"file": ("x.pdf", b"data", "application/pdf")},
            data={"asset_type": "video"},
        )
        assert resp.status_code == 400

    def test_upload_media_piece_not_found(self):
        resp = client.post(
            "/api/v1/pieces/99999/media",
            files={"file": ("x.pdf", b"data", "application/pdf")},
            data={"asset_type": "scan"},
        )
        assert resp.status_code == 404

    # -- history drafts --
    def test_history_drafts_list_empty(self):
        with TestingSessionLocal() as db:
            piece = _create_piece(db, "Drafts Test")
            pid = piece.id

        resp = client.get(f"/api/v1/pieces/{pid}/history-drafts")
        assert resp.status_code == 200
        assert resp.json() == []

    def test_history_drafts_crud(self):
        with TestingSessionLocal() as db:
            piece = _create_piece(db, "Draft CRUD")
            pid = piece.id

        # create
        resp = client.post(
            f"/api/v1/pieces/{pid}/history-drafts",
            json={"note": "First draft", "page": 1},
        )
        assert resp.status_code == 200
        draft_id = resp.json()["id"]

        # list
        resp = client.get(f"/api/v1/pieces/{pid}/history-drafts")
        assert resp.status_code == 200
        assert len(resp.json()) == 1

        # update
        resp = client.patch(
            f"/api/v1/pieces/{pid}/history-drafts/{draft_id}",
            json={"note": "Updated draft"},
        )
        assert resp.status_code == 200
        assert resp.json()["note"] == "Updated draft"

        # delete
        resp = client.delete(f"/api/v1/pieces/{pid}/history-drafts/{draft_id}")
        assert resp.status_code == 200

        # verify gone
        resp = client.get(f"/api/v1/pieces/{pid}/history-drafts")
        assert resp.status_code == 200
        assert resp.json() == []

    def test_history_drafts_piece_not_found(self):
        resp = client.post(
            "/api/v1/pieces/99999/history-drafts",
            json={"note": "x", "page": 1},
        )
        assert resp.status_code == 404


# ===========================================================================
# Jobs Router
# ===========================================================================


class TestJobs:
    """Job queuing, status updates, and 404 handling."""

    def test_list_jobs_empty(self):
        resp = client.get("/api/v1/jobs/")
        assert resp.status_code == 200
        assert resp.json() == []

    def test_trigger_job(self):
        resp = client.post(
            "/api/v1/jobs/trigger",
            json={"action": "analyze", "piece_id": None},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["action"] == "analyze"
        assert data["status"] == JobStatus.pending

    def test_trigger_job_missing_action(self):
        resp = client.post("/api/v1/jobs/trigger", json={})
        assert resp.status_code == 422

    def test_get_job(self):
        resp = client.post(
            "/api/v1/jobs/trigger",
            json={"action": "transcribe"},
        )
        job_id = resp.json()["id"]

        resp = client.get(f"/api/v1/jobs/{job_id}")
        assert resp.status_code == 200
        assert resp.json()["action"] == "transcribe"

    def test_update_job_status(self):
        resp = client.post(
            "/api/v1/jobs/trigger",
            json={"action": "process"},
        )
        job_id = resp.json()["id"]

        resp = client.patch(
            f"/api/v1/jobs/{job_id}",
            json={"status": JobStatus.running, "progress": 50},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == JobStatus.running
        assert data["progress"] == 50

    def test_get_job_not_found(self):
        resp = client.get("/api/v1/jobs/99999")
        assert resp.status_code == 404

    def test_update_job_not_found(self):
        resp = client.patch("/api/v1/jobs/99999", json={"status": JobStatus.completed})
        assert resp.status_code == 404


# ===========================================================================
# Sync Router
# ===========================================================================


class TestSync:
    """Client sync state: defaults, upload, download."""

    def test_sync_new_client_defaults(self):
        resp = client.get("/api/v1/sync/test-client-001")
        assert resp.status_code == 200
        data = resp.json()
        assert data["pending_uploads"] == 0
        assert data["pending_downloads"] == 0

    def test_sync_update_upload(self):
        client.post("/api/v1/sync/test-client-002/upload", json={"piece_ids": [1, 2]})

        resp = client.get("/api/v1/sync/test-client-002")
        assert resp.status_code == 200
        data = resp.json()
        assert data["pending_uploads"] == 2

    def test_sync_update_download(self):
        client.post("/api/v1/sync/test-client-003/download", json={"piece_ids": [3]})

        resp = client.get("/api/v1/sync/test-client-003")
        assert resp.status_code == 200
        data = resp.json()
        assert data["pending_downloads"] == 1

    def test_sync_combined(self):
        client.post("/api/v1/sync/test-client-004/upload", json={"piece_ids": [1]})
        client.post("/api/v1/sync/test-client-004/download", json={"piece_ids": [2]})

        resp = client.get("/api/v1/sync/test-client-004")
        assert resp.status_code == 200
        data = resp.json()
        assert data["pending_uploads"] == 1
        assert data["pending_downloads"] == 1

    def test_sync_reset(self):
        client.post("/api/v1/sync/test-client-005/upload", json={"piece_ids": [1]})
        client.post("/api/v1/sync/test-client-005/reset")

        resp = client.get("/api/v1/sync/test-client-005")
        assert resp.status_code == 200
        data = resp.json()
        assert data["pending_uploads"] == 0
        assert data["pending_downloads"] == 0


# ===========================================================================
# Review Router
# ===========================================================================


class TestReview:
    """Review workflow: create items, approve/reject, auto-transition."""

    # -- create review item --
    def test_create_review_item(self):
        with TestingSessionLocal() as db:
            piece = _create_piece(db, "Review Piece", status=PieceStatus.draft)
            pid = piece.id

        resp = client.post(
            "/api/v1/review/",
            json={"piece_id": pid, "item_type": "technique", "comment": "Bow grip"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["piece_id"] == pid
        assert data["status"] == "pending"

        # piece should now be review_pending
        with TestingSessionLocal() as db:
            db.refresh(piece)
            assert piece.status == PieceStatus.review_pending

    def test_create_review_item_already_pending(self):
        with TestingSessionLocal() as db:
            piece = _create_piece(db, "Already Pending", status=PieceStatus.review_pending)
            pid = piece.id

        resp = client.post(
            "/api/v1/review/",
            json={"piece_id": pid, "item_type": "technique", "comment": "x"},
        )
        assert resp.status_code == 409

    def test_create_review_item_piece_not_found(self):
        resp = client.post(
            "/api/v1/review/",
            json={"piece_id": 99999, "item_type": "technique", "comment": "x"},
        )
        assert resp.status_code == 404

    # -- resolve review item --
    def test_approve_review_item(self):
        with TestingSessionLocal() as db:
            piece = _create_piece(db, "Approve Test", status=PieceStatus.draft)
            pid = piece.id
            item = ReviewItem(piece_id=pid, item_type="technique", comment="Good", status=ReviewAction.approved)
            db.add(item)
            db.commit()
            db.refresh(item)
            item_id = item.id

        resp = client.post(f"/api/v1/review/{item_id}", json={"action": "approve"})
        assert resp.status_code == 200

    def test_reject_review_item(self):
        with TestingSessionLocal() as db:
            piece = _create_piece(db, "Reject Test", status=PieceStatus.draft)
            pid = piece.id
            item = ReviewItem(piece_id=pid, item_type="technique", comment="Bad", status=ReviewAction.rejected)
            db.add(item)
            db.commit()
            db.refresh(item)
            item_id = item.id

        resp = client.post(f"/api/v1/review/{item_id}", json={"action": "reject"})
        assert resp.status_code == 200

    def test_resolve_review_item_not_found(self):
        resp = client.post("/api/v1/review/99999", json={"action": "approve"})
        assert resp.status_code == 404

    def test_resolve_review_item_already_resolved(self):
        with TestingSessionLocal() as db:
            piece = _create_piece(db, "Resolved", status=PieceStatus.draft)
            pid = piece.id
            item = ReviewItem(piece_id=pid, item_type="technique", comment="x", status=ReviewAction.approved)
            db.add(item)
            db.commit()
            db.refresh(item)
            item_id = item.id

        resp = client.post(f"/api/v1/review/{item_id}", json={"action": "approve"})
        assert resp.status_code == 409

    # -- auto-transition edge case --
    def test_approve_last_pending_transitions_to_approved(self):
        with TestingSessionLocal() as db:
            piece = _create_piece(db, "Auto Transition", status=PieceStatus.draft)
            pid = piece.id

        # Create two review items
        resp1 = client.post(
            "/api/v1/review/",
            json={"piece_id": pid, "item_type": "technique", "comment": "Item 1"},
        )
        item1_id = resp1.json()["id"]

        resp2 = client.post(
            "/api/v1/review/",
            json={"piece_id": pid, "item_type": "expression", "comment": "Item 2"},
        )
        item2_id = resp2.json()["id"]

        # Approve first item — piece should NOT transition yet
        client.post(f"/api/v1/review/{item1_id}", json={"action": "approve"})

        with TestingSessionLocal() as db:
            db.execute(text(f"SELECT status FROM pieces WHERE id = {pid}"))
            row = db.execute(text("SELECT status FROM pieces WHERE id = :pid"), {"pid": pid}).fetchone()
            assert row[0] == PieceStatus.review_pending

        # Approve second (last pending) item — piece should transition to approved
        client.post(f"/api/v1/review/{item2_id}", json={"action": "approve"})

        with TestingSessionLocal() as db:
            row = db.execute(text("SELECT status FROM pieces WHERE id = :pid"), {"pid": pid}).fetchone()
            assert row[0] == PieceStatus.approved

    def test_reject_one_approve_other_still_pending(self):
        with TestingSessionLocal() as db:
            piece = _create_piece(db, "Mixed Results", status=PieceStatus.draft)
            pid = piece.id

        resp1 = client.post(
            "/api/v1/review/",
            json={"piece_id": pid, "item_type": "technique", "comment": "Item 1"},
        )
        item1_id = resp1.json()["id"]

        resp2 = client.post(
            "/api/v1/review/",
            json={"piece_id": pid, "item_type": "expression", "comment": "Item 2"},
        )
        item2_id = resp2.json()["id"]

        # Reject first, approve second — piece stays review_pending
        client.post(f"/api/v1/review/{item1_id}", json={"action": "reject"})
        client.post(f"/api/v1/review/{item2_id}", json={"action": "approve"})

        with TestingSessionLocal() as db:
            row = db.execute(text("SELECT status FROM pieces WHERE id = :pid"), {"pid": pid}).fetchone()
            assert row[0] == PieceStatus.review_pending
