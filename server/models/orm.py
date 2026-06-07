"""SQLAlchemy ORM models for the AZMusic server.

Entities:
- Profile: family member / student account
- Piece: imported sheet music document
- ScoreVersion: a parsed score file (raw, reconstructed, approved)
- AnnotationLayer: user annotations on a score version
- MediaAsset: uploaded images, scans, or audio
- PieceHistoryDraft: AI-generated score draft with provenance
- ReviewItem: pending review task for the student/parent
- BackgroundJob: queued or running background task
- SyncState: client-side sync checkpoint
"""

import uuid
from datetime import datetime
from enum import StrEnum
from typing import Optional

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Index, Integer, String, Text
from sqlalchemy.dialects.sqlite import JSON
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


# ── Enums ───────────────────────────────────────────────────────────────────

class PieceStatus(StrEnum):
    imported = "imported"
    processing = "processing"
    review_pending = "review_pending"
    approved = "approved"
    needs_edits = "needs_edits"
    archived = "archived"


class ScoreVersionType(StrEnum):
    raw = "raw"
    reconstructed_candidate = "reconstructed_candidate"
    approved = "approved"
    rejected = "rejected"


class JobStatus(StrEnum):
    queued = "queued"
    running = "running"
    succeeded = "succeeded"
    failed = "failed"
    canceled = "canceled"


class ReviewItemType(StrEnum):
    score_candidate = "score_candidate"
    media_candidate = "media_candidate"
    piece_history = "piece_history"


class ReviewAction(StrEnum):
    approve = "approve"
    reject = "reject"


# ── Models ──────────────────────────────────────────────────────────────────

def _uuid():
    return str(uuid.uuid4())


class Profile(Base):
    """A family member or student account."""

    __tablename__ = "profiles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    role: Mapped[str] = mapped_column(String(50), default="student")  # student, parent, teacher
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    pieces: Mapped[list["Piece"]] = relationship(back_populates="owner")


class Piece(Base):
    """An imported sheet music document."""

    __tablename__ = "pieces"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    composer: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)
    file_name: Mapped[str] = mapped_column(String(500), nullable=False)
    status: Mapped[str] = mapped_column(
        String(20), default=PieceStatus.imported, index=True
    )
    key_signature: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    tempo: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    difficulty_level: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    owner_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("profiles.id"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    owner: Mapped[Optional["Profile"]] = relationship(back_populates="pieces")
    score_versions: Mapped[list["ScoreVersion"]] = relationship(
        back_populates="piece", cascade="all, delete-orphan"
    )
    media_assets: Mapped[list["MediaAsset"]] = relationship(
        back_populates="piece", cascade="all, delete-orphan"
    )
    history_drafts: Mapped[list["PieceHistoryDraft"]] = relationship(
        back_populates="piece", cascade="all, delete-orphan"
    )
    review_items: Mapped[list["ReviewItem"]] = relationship(
        back_populates="piece", cascade="all, delete-orphan"
    )
    annotations: Mapped[list["AnnotationLayer"]] = relationship(
        back_populates="piece", cascade="all, delete-orphan"
    )


class ScoreVersion(Base):
    """A parsed version of a score (raw OCR, AI reconstruction, approved)."""

    __tablename__ = "score_versions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    piece_id: Mapped[str] = mapped_column(
        ForeignKey("pieces.id", ondelete="CASCADE"), nullable=False
    )
    version_type: Mapped[str] = mapped_column(
        String(30), default=ScoreVersionType.raw
    )
    file_path: Mapped[str] = mapped_column(String(1000), nullable=False)
    is_default: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    piece: Mapped["Piece"] = relationship(back_populates="score_versions")

    __table_args__ = (
        Index("ix_score_versions_piece_default", "piece_id", "is_default"),
    )


class AnnotationLayer(Base):
    """User annotations on a score version (fingerings, bowings, marks)."""

    __tablename__ = "annotation_layers"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    piece_id: Mapped[str] = mapped_column(
        ForeignKey("pieces.id", ondelete="CASCADE"), nullable=False
    )
    score_version_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("score_versions.id", ondelete="SET NULL"), nullable=True
    )
    label: Mapped[str] = mapped_column(String(200), nullable=False)
    content: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    piece: Mapped["Piece"] = relationship(back_populates="annotations")


class MediaAsset(Base):
    """Uploaded media files (images, scans, audio recordings)."""

    __tablename__ = "media_assets"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    piece_id: Mapped[str] = mapped_column(
        ForeignKey("pieces.id", ondelete="CASCADE"), nullable=False
    )
    asset_type: Mapped[str] = mapped_column(String(50), nullable=False)  # image, scan, audio
    file_path: Mapped[str] = mapped_column(String(1000), nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="approved")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    piece: Mapped["Piece"] = relationship(back_populates="media_assets")


class PieceHistoryDraft(Base):
    """AI-generated score draft with provenance tracking."""

    __tablename__ = "piece_history_drafts"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    piece_id: Mapped[str] = mapped_column(
        ForeignKey("pieces.id", ondelete="CASCADE"), nullable=False
    )
    content: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="approved")
    confidence: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    provenance: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    piece: Mapped["Piece"] = relationship(back_populates="history_drafts")


class ReviewItem(Base):
    """A pending review task for the student or parent."""

    __tablename__ = "review_items"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    piece_id: Mapped[str] = mapped_column(
        ForeignKey("pieces.id", ondelete="CASCADE"), nullable=False
    )
    item_type: Mapped[str] = mapped_column(String(30), nullable=False)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(20), default="pending")
    candidate_data: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    piece: Mapped["Piece"] = relationship(back_populates="review_items")


class BackgroundJob(Base):
    """A background processing job (OCR, reconstruction, sync)."""

    __tablename__ = "background_jobs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    piece_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("pieces.id", ondelete="SET NULL"), nullable=True
    )
    job_type: Mapped[str] = mapped_column(String(100), nullable=False)
    status: Mapped[str] = mapped_column(
        String(20), default=JobStatus.queued, index=True
    )
    progress: Mapped[float] = mapped_column(Float, default=0.0)
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    result_data: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    piece: Mapped[Optional["Piece"]] = relationship()


class SyncState(Base):
    """Client-side sync checkpoint for offline sync."""

    __tablename__ = "sync_states"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    client_id: Mapped[str] = mapped_column(
        String(36), unique=True, nullable=False, index=True
    )
    last_sync: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    pending_uploads: Mapped[int] = mapped_column(Integer, default=0)
    pending_downloads: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )
