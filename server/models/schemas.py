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
    needs_edits = "needs_edits"
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
    canceled = "canceled"


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


class PiecePushMode(str, Enum):
    processed = "processed"
    cleaned_pdf = "cleaned_pdf"
    original_pdf = "original_pdf"


class OmrStrategy(str, Enum):
    audiveris_default = "audiveris_default"
    audiveris_quality_sweep = "audiveris_quality_sweep"
    homr_experimental = "homr_experimental"
    legato_experimental = "legato_experimental"
    omr_bakeoff = "omr_bakeoff"
    experimental_engine_bakeoff = "experimental_engine_bakeoff"


class PieceKind(str, Enum):
    piece = "piece"
    book = "book"


class ReviewReprocessType(str, Enum):
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
    mode: PiecePushMode = PiecePushMode.cleaned_pdf


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
    selected_candidate_id: Optional[str] = Field(default=None, min_length=1, max_length=100)


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
    homr_cli_path: Optional[str] = None
    legato_cli_path: Optional[str] = None
    legato_model_path: Optional[str] = None
    musescore_cli_path: Optional[str] = None
    musescore_style_path: Optional[str] = None
    ocr_cli_path: Optional[str] = None
    ocr_language: Optional[str] = None
    ocr_effort: Optional[str] = None
    omr_strategy: Optional[OmrStrategy] = None
    max_concurrent_jobs: Optional[int] = Field(default=None, ge=1, le=4)
    processing_mode: Optional[ProcessingMode] = None
    allow_stub_musicxml: Optional[bool] = None
    local_llm_provider: Optional[str] = None
    local_llm_model: Optional[str] = None
    local_llm_base_url: Optional[str] = None
    cloud_enabled: Optional[bool] = None
    cloud_provider: Optional[str] = None
    cloud_model: Optional[str] = None
    cloud_base_url: Optional[str] = None
    cloud_api_key: Optional[str] = None
    cloud_auth_mode: Optional[str] = None


class ProcessingSettingsResponse(BaseModel):
    audiveris_cli_path: Optional[str] = None
    homr_cli_path: Optional[str] = None
    legato_cli_path: Optional[str] = None
    legato_model_path: Optional[str] = None
    musescore_cli_path: Optional[str] = None
    musescore_style_path: Optional[str] = None
    ocr_cli_path: Optional[str] = None
    ocr_language: str = "eng"
    ocr_effort: str = "balanced"
    omr_strategy: OmrStrategy = OmrStrategy.audiveris_default
    max_concurrent_jobs: int = Field(default=2, ge=1, le=4)
    processing_mode: ProcessingMode = ProcessingMode.server_only
    allow_stub_musicxml: bool = True
    production_mode: bool = False
    last_processing_error: Optional[str] = None
    local_llm_provider: Optional[str] = None
    local_llm_model: Optional[str] = None
    local_llm_base_url: Optional[str] = None
    last_llm_processing_error: Optional[str] = None
    cloud_enabled: bool = False
    cloud_provider: Optional[str] = None
    cloud_model: Optional[str] = None
    cloud_base_url: Optional[str] = None
    cloud_api_key_configured: bool = False
    cloud_auth_mode: str = "oauth"
    cloud_oauth_connected: bool = False
    cloud_oauth_account: Optional[str] = None
    last_cloud_processing_error: Optional[str] = None
    updated_at: datetime


class GeminiOAuthStatusResponse(BaseModel):
    provider: str = "gemini"
    auth_mode: str = "oauth"
    configured: bool = False
    connected: bool = False
    available: bool = False
    account_email: Optional[str] = None
    model: str = "gemini-2.5-flash"
    error: Optional[str] = None
    scopes: list[str] = Field(default_factory=list)
    authorization_url: Optional[str] = None
    updated_at: Optional[datetime] = None


class GeminiOAuthStartResponse(BaseModel):
    authorization_url: str
    state: str
    redirect_uri: str
    expires_at: datetime


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
    homr: ProcessingExecutableStatus
    legato: ProcessingExecutableStatus
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


class JobSummaryActiveJobResponse(BaseModel):
    id: str
    piece_id: Optional[str] = None
    piece_title: Optional[str] = None
    piece_composer: Optional[str] = None
    piece_status: Optional[str] = None
    job_type: str
    status: JobStatus
    progress: float = 0.0
    error_message: Optional[str] = None
    result_data: Optional[dict] = None
    created_at: datetime
    updated_at: datetime


class JobSummaryResponse(BaseModel):
    queued_count: int = 0
    running_count: int = 0
    failed_count: int = 0
    succeeded_count: int = 0
    canceled_count: int = 0
    active_jobs: list[JobSummaryActiveJobResponse] = Field(default_factory=list)
    last_failed_job: Optional[JobSummaryFailureResponse] = None


class ProcessingCapabilityResponse(BaseModel):
    server_online: bool = True
    settings: ProcessingSettingsResponse
    audiveris: ProcessingExecutableStatus
    homr: ProcessingExecutableStatus
    legato: ProcessingExecutableStatus
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
    workflow_closed: bool = False
    visible_to_profile_ids: list[str] = []
    previous_visible_to_profile_ids: list[str] = []
    library_status: str = "intake"
    source_content_sha256: Optional[str] = None
    source_book_fingerprint: Optional[str] = None
    logical_piece_key: Optional[str] = None
    canonical_piece_id: Optional[str] = None
    attempt_status: str = "canonical"
    duplicate_attempt_count: int = 0
    duplicate_reason: Optional[str] = None
    is_duplicate_attempt: bool = False
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
    score_version_role: Optional[str] = None
    artifact_role: Optional[str] = None
    replaces_score_version_id: Optional[str] = None
    display_rank: int = 0
    student_default: bool = False
    approved_by_parent: bool = False
    is_default: bool = False
    created_at: datetime


class CloudConnectGithubRequest(BaseModel):
    repository: Optional[str] = Field(default=None, max_length=300)
    branch: str = Field(default="main", min_length=1, max_length=100)
    path_prefix: str = Field(default="azmusic-sync", min_length=1, max_length=200)


class CloudStatusResponse(BaseModel):
    provider: str = "github"
    configured: bool = False
    connected: bool = False
    account_scope: str = "parent_teacher"
    repository: Optional[str] = None
    branch: str = "main"
    path_prefix: str = "azmusic-sync"
    last_sync_at: Optional[datetime] = None
    last_restore_at: Optional[datetime] = None
    last_error: Optional[str] = None
    notes: list[str] = Field(default_factory=list)


class CloudSyncManifestResponse(BaseModel):
    provider: str = "github"
    family_manifest_path: str
    pieces_count: int = 0
    score_versions_count: int = 0
    assignments_count: int = 0
    notes_count: int = 0
    annotations_count: int = 0
    synced_at: datetime


class NoteSyncItem(BaseModel):
    id: str = Field(..., min_length=1, max_length=100)
    profile_id: str = Field(..., min_length=1, max_length=100)
    piece_id: str = Field(..., min_length=1, max_length=100)
    score_version_id: Optional[str] = Field(default=None, max_length=100)
    page_number: Optional[int] = Field(default=None, ge=1)
    payload: dict = Field(default_factory=dict)
    updated_at: Optional[datetime] = None
    deleted: bool = False


class NoteSyncRequest(BaseModel):
    client_id: str = Field(..., min_length=1, max_length=100)
    profile_id: str = Field(..., min_length=1, max_length=100)
    notes: list[NoteSyncItem] = Field(default_factory=list)


class NoteSyncResponse(BaseModel):
    client_id: str
    profile_id: str
    accepted_count: int = 0
    notes: list[NoteSyncItem] = Field(default_factory=list)
    synced_at: datetime


class AnnotationSyncItem(BaseModel):
    id: str = Field(..., min_length=1, max_length=100)
    profile_id: str = Field(..., min_length=1, max_length=100)
    piece_id: str = Field(..., min_length=1, max_length=100)
    score_version_id: Optional[str] = Field(default=None, max_length=100)
    page_number: int = Field(..., ge=1)
    payload: dict = Field(default_factory=dict)
    updated_at: Optional[datetime] = None
    deleted: bool = False


class AnnotationSyncRequest(BaseModel):
    client_id: str = Field(..., min_length=1, max_length=100)
    profile_id: str = Field(..., min_length=1, max_length=100)
    annotations: list[AnnotationSyncItem] = Field(default_factory=list)


class AnnotationSyncResponse(BaseModel):
    client_id: str
    profile_id: str
    accepted_count: int = 0
    annotations: list[AnnotationSyncItem] = Field(default_factory=list)
    synced_at: datetime


class MediaAssetResponse(BaseModel):
    id: str
    piece_id: str
    asset_type: str
    file_path: Optional[str] = None
    status: str = "approved"
    created_at: datetime

    # YouTube reference fields
    youtube_video_id: Optional[str] = None
    thumbnail_url: Optional[str] = None
    local_file_path: Optional[str] = None
    is_approved: bool = False
    pushed_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class MediaCandidateResponse(BaseModel):
    """Staged YouTube candidate for parent review dashboard."""

    id: str
    piece_id: str
    youtube_video_id: str
    title: str
    thumbnail_url: Optional[str] = None
    is_approved: bool = False
    pushed_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class MediaPushRequest(BaseModel):
    """Request to approve and download a media asset."""

    pass


class MediaRevokeResponse(BaseModel):
    id: str
    is_approved: bool
    updated_at: datetime


class MediaSyncItem(BaseModel):
    """Media attachment pushed to client during sync delta."""

    id: str = Field(..., min_length=1, max_length=100)
    piece_id: str = Field(..., min_length=1, max_length=100)
    youtube_video_id: Optional[str] = None
    title: str = Field(..., min_length=1, max_length=500)
    thumbnail_url: Optional[str] = None
    download_url: str = Field(..., min_length=1)
    file_size_bytes: Optional[int] = None
    content_sha256: Optional[str] = None


class MediaSyncPayload(BaseModel):
    """Media delta included in sync response."""

    media_attachments: list[MediaSyncItem] = Field(default_factory=list)
    media_deletions: list[str] = Field(default_factory=list)


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
    piece_title: Optional[str] = None
    piece_composer: Optional[str] = None
    piece_status: Optional[str] = None
    job_type: str
    status: JobStatus
    progress: float = 0.0
    error_message: Optional[str] = None
    result_data: Optional[dict] = None
    created_at: datetime
    updated_at: datetime


class PracticeAlertItem(BaseModel):
    """Unread recording request for a student's alert feed."""

    id: str
    teacher_profile_id: str
    teacher_name: str
    student_profile_id: str
    piece_id: Optional[str] = None
    piece_title: Optional[str] = None
    message_notes: Optional[str] = None
    is_read: bool = False
    created_at: datetime


class PracticeAlertsResponse(BaseModel):
    pending_requests: list[PracticeAlertItem] = Field(default_factory=list)


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
    pending_requests: list[PracticeAlertItem] = Field(default_factory=list)


PieceResponse.model_rebuild()
PieceDetailResponse.model_rebuild()


class PracticeRecordingCreate(BaseModel):
    """Request body for uploading a practice recording."""

    piece_id: str = Field(..., min_length=1, max_length=36)
    local_file_path: Optional[str] = None


class PracticeRecordingResponse(BaseModel):
    id: str
    student_profile_id: str
    piece_id: str
    local_file_path: Optional[str] = None
    submitted_at: datetime


class RecordingRequestCreate(BaseModel):
    """Request body for creating a teacher/parent recording request or note."""

    student_profile_id: str = Field(..., min_length=1, max_length=36)
    piece_id: Optional[str] = Field(default=None, max_length=36)
    message_notes: Optional[str] = Field(default=None, max_length=5000)


class RecordingRequestResponse(BaseModel):
    id: str
    teacher_profile_id: str
    student_profile_id: str
    piece_id: Optional[str] = None
    message_notes: Optional[str] = None
    is_read: bool = False
    created_at: datetime
