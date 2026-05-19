"""Pydantic request/response models for the AZMusic API."""

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class PieceStatus(str, Enum):
    imported = "imported"
    processing = "processing"
    review_pending = "review_pending"
    approved = "approved"
    archived = "archived"


class ScoreVersionType(str, Enum):
    raw = "raw"
    reconstructed_candidate = "reconstructed_candidate"
    approved = "approved"
    rejected = "rejected"


class JobStatus(str, Enum):
    queued = "queued"
    running = "running"
    succeeded = "succeeded"
    failed = "failed"


class ReviewItemType(str, Enum):
    score_candidate = "score_candidate"
    media_candidate = "media_candidate"
    piece_history = "piece_history"


class ReviewAction(str, Enum):
    approve = "approve"
    reject = "reject"


class PieceCreate(BaseModel):
    """Request body for importing a new piece."""

    title: str = Field(..., min_length=1, max_length=500)
    composer: Optional[str] = Field(None, max_length=300)
    file_name: str = Field(..., max_length=500)
    piece_id: Optional[str] = None


class PieceUpdate(BaseModel):
    """Light metadata corrections from review."""

    title: Optional[str] = None
    composer: Optional[str] = None
    primary_instrument: Optional[str] = None
    book_or_collection: Optional[str] = None
    key_signature: Optional[str] = None
    tempo: Optional[str] = None
    difficulty_level: Optional[str] = None


class PiecePushRequest(BaseModel):
    profile_ids: list[str] = Field(default_factory=list)


class PieceHistoryDraftCreate(BaseModel):
    """Request body for creating a history draft for a piece."""

    content: str = Field(..., min_length=1)
    status: str = Field(default="approved", max_length=20)
    confidence: Optional[float] = None
    provenance: Optional[str] = Field(default=None, max_length=200)


class ReviewItemCreate(BaseModel):
    """Request body for creating a review item."""

    piece_id: str
    item_type: ReviewItemType
    title: str = Field(..., min_length=1, max_length=500)
    description: str = Field(default="")
    candidate_data: Optional[dict] = None


class ReviewItemRequest(BaseModel):
    """Request to approve or reject a review item."""

    action: ReviewAction
    notes: Optional[str] = None
    correction: Optional[dict] = None


class JobStatusRequest(BaseModel):
    """Request to poll job status."""

    job_id: str


class JobTriggerRequest(BaseModel):
    """Request body for queueing a background job."""

    job_type: str = Field(..., min_length=1, max_length=100)
    piece_id: Optional[str] = None


class JobUpdateRequest(BaseModel):
    """Request body for updating a background job."""

    status: Optional[JobStatus] = None
    progress: Optional[float] = Field(default=None, ge=0.0, le=100.0)
    error_message: Optional[str] = None
    result_data: Optional[dict] = None


class SyncUploadRequest(BaseModel):
    """Request body for updating pending upload counts."""

    pending_uploads: int = Field(default=0, ge=0)


class SyncDownloadRequest(BaseModel):
    """Request body for updating pending download counts."""

    pending_downloads: int = Field(default=0, ge=0)
    last_sync: Optional[datetime] = None


class PieceResponse(BaseModel):
    """Single piece summary."""

    id: str
    title: str
    composer: Optional[str] = None
    primary_instrument: Optional[str] = None
    book_or_collection: Optional[str] = None
    visible_to_profile_ids: list[str] = []
    library_status: str = "intake"
    status: PieceStatus
    created_at: datetime
    updated_at: datetime


class PieceDetailResponse(PieceResponse):
    """Full piece detail including score versions and metadata."""

    file_name: str
    score_versions: list["ScoreVersionResponse"] = []
    media_assets: list["MediaAssetResponse"] = []
    history_drafts: list["PieceHistoryDraftResponse"] = []


class ScoreVersionResponse(BaseModel):
    id: str
    piece_id: str
    version_type: ScoreVersionType
    file_path: str
    file_url: Optional[str] = None
    is_default: bool = False
    created_at: datetime


class MediaAssetResponse(BaseModel):
    id: str
    piece_id: str
    asset_type: str
    file_path: str
    status: str = "approved"
    created_at: datetime


class PieceHistoryDraftResponse(BaseModel):
    id: str
    piece_id: str
    content: str
    status: str = "approved"
    confidence: Optional[float] = None
    provenance: Optional[str] = None
    created_at: datetime


class ReviewItemResponse(BaseModel):
    id: str
    piece_id: str
    item_type: ReviewItemType
    title: str
    description: str
    status: str = "pending"
    created_at: datetime
    candidate_data: Optional[dict] = None


class JobResponse(BaseModel):
    id: str
    piece_id: str
    job_type: str
    status: JobStatus
    progress: float = 0.0
    error_message: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class SyncStateResponse(BaseModel):
    client_id: str
    last_sync: Optional[datetime] = None
    pending_uploads: int = 0
    pending_downloads: int = 0


PieceResponse.model_rebuild()
PieceDetailResponse.model_rebuild()
