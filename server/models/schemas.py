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


class SyncStateStatus(str, Enum):
    offline_ready = "offline-ready"
    syncing = "syncing"
    synced = "synced"
    sync_failed_usable = "sync-failed-usable"


class ProcessingMode(str, Enum):
    server_only = "server_only"
    server_plus_device_workers = "server_plus_device_workers"
    server_plus_cloud_workers = "server_plus_cloud_workers"
    server_plus_device_and_cloud_workers = "server_plus_device_and_cloud_workers"


class PieceKind(str, Enum):
    piece = "piece"
    book = "book"


class ReviewReprocessType(str, Enum):
    metadata = "metadata"
    split = "split"
    score = "score"


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
    notes: Optional[str] = None
    piece_kind: Optional[PieceKind] = None
    source_book_id: Optional[str] = None
    source_page_start: Optional[int] = Field(default=None, ge=1)
    source_page_end: Optional[int] = Field(default=None, ge=1)
    catalog_metadata: Optional[dict] = None
    catalog_suggestions: Optional[list[dict]] = None
    validation_warnings: Optional[list[str]] = None


class PiecePushRequest(BaseModel):
    profile_ids: list[str] = Field(default_factory=list)


class ScoreVersionRerenderRequest(BaseModel):
    rendered_score_version_id: str


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


class ReviewBulkApprovalRequest(BaseModel):
    """Request to approve all matching review items for a source book."""

    source_book_id: Optional[str] = Field(default=None, min_length=1)
    source_review_item_id: Optional[str] = Field(default=None, min_length=1)
    processing_stage: str = Field(..., min_length=1, max_length=100)


class ReviewBulkApprovalResponse(BaseModel):
    source_book_id: str
    processing_stage: str
    approved_count: int = 0
    skipped_count: int = 0
    failed_count: int = 0
    approved_item_ids: list[str] = Field(default_factory=list)
    skipped_item_ids: list[str] = Field(default_factory=list)
    failed_items: list[dict] = Field(default_factory=list)


class ReviewReprocessRequest(BaseModel):
    """Request follow-up processing for a review item without approving it."""

    reprocess_type: ReviewReprocessType
    parent_notes: Optional[str] = Field(default=None, max_length=2000)


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


class SyncStateUpdateRequest(BaseModel):
    """Request body for patching sync banner and retry bookkeeping."""

    pending_uploads: Optional[int] = Field(default=None, ge=0)
    pending_downloads: Optional[int] = Field(default=None, ge=0)
    last_sync: Optional[datetime] = None
    status: Optional[SyncStateStatus] = None
    retry_required: Optional[bool] = None
    last_attempt_at: Optional[datetime] = None
    last_success_at: Optional[datetime] = None
    last_failure_at: Optional[datetime] = None
    last_error: Optional[str] = Field(default=None, max_length=2000)


class ProcessingSettingsUpdate(BaseModel):
    """Durable server processing settings managed from the parent app."""

    audiveris_cli_path: Optional[str] = None
    musescore_cli_path: Optional[str] = None
    ocr_cli_path: Optional[str] = None
    ocr_language: Optional[str] = None
    processing_mode: Optional[ProcessingMode] = None
    allow_stub_musicxml: Optional[bool] = None
    local_llm_provider: Optional[str] = None
    local_llm_model: Optional[str] = None
    cloud_enabled: Optional[bool] = None
    cloud_provider: Optional[str] = None
    cloud_model: Optional[str] = None
    cloud_base_url: Optional[str] = None
    cloud_api_key: Optional[str] = None


class ProcessingSettingsResponse(BaseModel):
    audiveris_cli_path: Optional[str] = None
    musescore_cli_path: Optional[str] = None
    ocr_cli_path: Optional[str] = None
    ocr_language: str = "eng"
    processing_mode: ProcessingMode = ProcessingMode.server_only
    allow_stub_musicxml: bool = True
    production_mode: bool = False
    last_processing_error: Optional[str] = None
    local_llm_provider: Optional[str] = None
    local_llm_model: Optional[str] = None
    last_llm_processing_error: Optional[str] = None
    cloud_enabled: bool = False
    cloud_provider: Optional[str] = None
    cloud_model: Optional[str] = None
    cloud_base_url: Optional[str] = None
    cloud_api_key_configured: bool = False
    last_cloud_processing_error: Optional[str] = None
    updated_at: datetime


class ProcessingExecutableStatus(BaseModel):
    name: str
    configured_path: Optional[str] = None
    discovered_path: Optional[str] = None
    configured: bool = False
    available: bool = False
    version: Optional[str] = None
    error: Optional[str] = None


class ProcessingValidationResponse(BaseModel):
    valid: bool
    audiveris: ProcessingExecutableStatus
    musescore: ProcessingExecutableStatus
    ocr: ProcessingExecutableStatus
    warnings: list[str] = Field(default_factory=list)


class DeviceWorkerRegistrationRequest(BaseModel):
    device_id: str = Field(..., min_length=1, max_length=200)
    device_name: str = Field(..., min_length=1, max_length=200)
    platform: str = Field(..., min_length=1, max_length=100)
    capabilities: list[str] = Field(default_factory=list)
    metadata: dict = Field(default_factory=dict)


class DeviceWorkerResponse(BaseModel):
    device_id: str
    device_name: str
    platform: str
    capabilities: list[str] = Field(default_factory=list)
    metadata: dict = Field(default_factory=dict)
    enabled: bool = True
    registered_at: datetime
    last_seen_at: datetime


class JobSummaryFailureResponse(BaseModel):
    id: str
    piece_id: Optional[str] = None
    job_type: str
    error_message: Optional[str] = None
    updated_at: datetime


class JobSummaryResponse(BaseModel):
    queued_count: int = 0
    running_count: int = 0
    failed_count: int = 0
    succeeded_count: int = 0
    last_failed_job: Optional[JobSummaryFailureResponse] = None


class ProcessingCapabilityResponse(BaseModel):
    server_online: bool = True
    settings: ProcessingSettingsResponse
    audiveris: ProcessingExecutableStatus
    musescore: ProcessingExecutableStatus
    ocr: ProcessingExecutableStatus
    local_llm: ProcessingExecutableStatus
    cloud_llm: ProcessingExecutableStatus
    device_workers_enabled: bool = False
    cloud_workers_enabled: bool = False
    device_workers: list[DeviceWorkerResponse] = Field(default_factory=list)
    job_summary: JobSummaryResponse = Field(default_factory=JobSummaryResponse)
    warnings: list[str] = Field(default_factory=list)


class PairingCodeResponse(BaseModel):
    server_id: str
    server_name: str
    server_url: str
    alternate_server_urls: list[str] = Field(default_factory=list)
    pairing_code: str
    pairing_uri: str
    qr_png_url: str
    expires_at: datetime
    purpose: str = "student_device"
    profile_id: Optional[str] = None
    profile_name: Optional[str] = None
    role: Optional[str] = None


class PairingClaimRequest(BaseModel):
    pairing_code: str = Field(..., min_length=1, max_length=100)
    device_id: str = Field(..., min_length=1, max_length=200)
    device_name: str = Field(..., min_length=1, max_length=200)
    platform: str = Field(..., min_length=1, max_length=100)


class PairingClaimResponse(BaseModel):
    server_id: str
    server_name: str
    server_url: str
    device_id: str
    device_token: str
    paired_at: datetime
    purpose: str = "student_device"
    profile_id: Optional[str] = None
    profile_name: Optional[str] = None
    role: Optional[str] = None


class PieceResponse(BaseModel):
    """Single piece summary."""

    id: str
    title: str
    composer: Optional[str] = None
    primary_instrument: Optional[str] = None
    book_or_collection: Optional[str] = None
    key_signature: Optional[str] = None
    tempo: Optional[str] = None
    difficulty_level: Optional[str] = None
    notes: Optional[str] = None
    processed_metadata: dict = Field(default_factory=dict)
    piece_kind: PieceKind = PieceKind.piece
    source_book_id: Optional[str] = None
    source_page_start: Optional[int] = None
    source_page_end: Optional[int] = None
    catalog_metadata: dict = Field(default_factory=dict)
    catalog_suggestions: list[dict] = Field(default_factory=list)
    validation_warnings: list[str] = Field(default_factory=list)
    split_confidence: Optional[float] = None
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
    content_type: Optional[str] = None
    file_size_bytes: Optional[int] = None
    content_sha256: Optional[str] = None
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
    piece_id: Optional[str] = None
    job_type: str
    status: JobStatus
    progress: float = 0.0
    error_message: Optional[str] = None
    result_data: Optional[dict] = None
    created_at: datetime
    updated_at: datetime


class SyncStateResponse(BaseModel):
    client_id: str
    last_sync: Optional[datetime] = None
    pending_uploads: int = 0
    pending_downloads: int = 0
    status: SyncStateStatus = SyncStateStatus.offline_ready
    has_pending_work: bool = False
    retry_required: bool = False
    last_attempt_at: Optional[datetime] = None
    last_success_at: Optional[datetime] = None
    last_failure_at: Optional[datetime] = None
    last_error: Optional[str] = None


PieceResponse.model_rebuild()
PieceDetailResponse.model_rebuild()
