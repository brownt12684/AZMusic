"""Router for score review and approval workflow."""

import uuid
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models.orm import (
    BackgroundJob,
    JobStatus,
    Piece,
    PieceStatus,
    ReviewAction,
    ReviewItem,
    ReviewItemType,
    ScoreVersion,
    ScoreVersionType,
)
from server.models.schemas import (
    JobResponse,
    ReviewBulkApprovalRequest,
    ReviewBulkApprovalResponse,
    ReviewItemCreate,
    ReviewItemRequest,
    ReviewItemResponse,
    ReviewReprocessRequest,
)
from server.services.gemini_vision import (
    GeminiVisionReviewAdapter,
    GeminiVisionReviewError,
)
from server.services.local_llm import LocalLlmProvider, LocalLlmUnavailableError
from server.services.piece_identity import (
    is_duplicate_metadata,
    supersede_duplicate_pending_reviews,
)
from server.services.piece_state import PieceStateService
from server.services.processing_engines import (
    MuseScoreRenderEngine,
    ProcessingEngineError,
    _normalize_musicxml_metadata,
    _validate_musicxml,
)
from server.services.processing_settings import ProcessingSettingsStore
from server.services.score_mcp_tools import (
    ScoreMcpToolController,
    ScoreMcpToolError,
    ScoreMcpToolResult,
)
from server.services.score_quality_loop import (
    build_hybrid_fallback_candidate,
    build_quality_loop_summary,
)
from server.services.score_visual_diff import ScoreVisualDiffError, compare_score_pdfs
from server.services.training_catalog import (
    TrainingCatalogError,
    catalog_notation_training_sample,
)

router = APIRouter()
_piece_state_service = PieceStateService()
_processing_settings_store = ProcessingSettingsStore()
_gemini_vision_adapter = GeminiVisionReviewAdapter()
_BULK_APPROVAL_STAGES = {
    "metadata_review_needed",
    "split_review_needed",
    "candidate_review_needed",
    "notation_edit_queued",
}
_METADATA_REVIEW_STAGES = {
    "metadata_review_needed",
    "split_review_needed",
}
_LOCAL_LLM_ALLOWED_SMALL_SCORE_TOOLS = {
    "update_note_pitch",
    "update_note_duration",
    "update_rest",
    "update_measure_time",
    "update_measure_key",
    "upsert_direction_words",
}
_LOCAL_LLM_EDIT_VERIFICATION_CONFIDENCE = 0.65
_LOCAL_LLM_MAX_ATTEMPTS_PER_TOOL = 2


def _file_url(request: Request, piece_id: str, score_version_id: str) -> str:
    return str(
        request.url_for(
            "get_score_version_file",
            piece_id=piece_id,
            score_version_id=score_version_id,
        )
    )


def _review_item_to_response(request: Request, item: ReviewItem) -> ReviewItemResponse:
    candidate_data = dict(item.candidate_data or {})
    raw_id = candidate_data.get("raw_score_version_id")
    rendered_id = candidate_data.get("score_version_id")
    canonical_id = candidate_data.get("canonical_score_version_id")

    if raw_id:
        candidate_data.setdefault(
            "raw_file_url",
            _file_url(request, item.piece_id, raw_id),
        )
    if rendered_id and _candidate_render_is_valid(candidate_data):
        candidate_data.setdefault(
            "rendered_file_url",
            _file_url(request, item.piece_id, rendered_id),
        )
    if canonical_id:
        candidate_data.setdefault(
            "canonical_file_url",
            _file_url(request, item.piece_id, canonical_id),
        )
    candidate_data = _with_omr_candidate_urls(request, item.piece_id, candidate_data)

    return ReviewItemResponse(
        id=item.id,
        piece_id=item.piece_id,
        item_type=item.item_type,
        title=item.title,
        description=item.description,
        status=item.status,
        created_at=item.created_at,
        candidate_data=candidate_data,
    )


@router.get("/")
async def list_review_items(
    request: Request,
    piece_id: str | None = None,
    include_resolved: bool = False,
    db: AsyncSession = Depends(get_db),
):
    """List pending review items, optionally filtered by piece."""
    query = select(ReviewItem).order_by(ReviewItem.created_at.desc())
    if piece_id:
        query = query.where(ReviewItem.piece_id == piece_id)
    if not include_resolved:
        query = query.where(ReviewItem.status == "pending")
    result = await db.execute(query)
    responses = []
    for item in result.scalars().all():
        if not include_resolved:
            piece = await db.get(Piece, item.piece_id)
            if piece and is_duplicate_metadata(_piece_state_service.metadata_for_piece(piece)):
                continue
        responses.append(_review_item_to_response(request, item))
    return responses


@router.post("/")
async def create_review_item(
    body: ReviewItemCreate,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Create a new review item for a piece."""
    piece = await db.get(Piece, body.piece_id)
    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")

    item = ReviewItem(
        id=str(uuid.uuid4()),
        piece_id=body.piece_id,
        item_type=body.item_type,
        title=body.title,
        description=body.description,
        status="pending",
        candidate_data=body.candidate_data,
        created_at=datetime.utcnow(),
    )
    db.add(item)

    if piece.status == PieceStatus.imported:
        piece.status = PieceStatus.review_pending

    await db.commit()
    await db.refresh(item)
    return _review_item_to_response(request, item)


@router.get("/{item_id}")
async def get_review_item(
    item_id: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Get a specific review item detail."""
    item = await db.get(ReviewItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Review item not found")
    return _review_item_to_response(request, item)


@router.post("/bulk/approve", response_model=ReviewBulkApprovalResponse)
async def bulk_approve_reviews(
    body: ReviewBulkApprovalRequest,
    db: AsyncSession = Depends(get_db),
):
    """Approve all pending review items from one book at the requested stage."""
    if body.processing_stage not in _BULK_APPROVAL_STAGES:
        raise HTTPException(
            status_code=400,
            detail=(
                "processing_stage must be metadata_review_needed, "
                "split_review_needed, candidate_review_needed, "
                "or notation_edit_queued."
            ),
        )

    source_book_id = body.source_book_id
    if not source_book_id and body.source_review_item_id:
        source_item = await db.get(ReviewItem, body.source_review_item_id)
        if source_item:
            source_book_id = await _source_book_id_for_review_item(db, source_item)
    if not source_book_id:
        raise HTTPException(
            status_code=400,
            detail="source_book_id or a resolvable source_review_item_id is required.",
        )

    result = await db.execute(select(ReviewItem).order_by(ReviewItem.created_at.asc()))
    approved_item_ids: list[str] = []
    skipped_item_ids: list[str] = []
    failed_items: list[dict] = []

    for item in result.scalars().all():
        candidate_data = dict(item.candidate_data or {})
        item_source_book_id = await _source_book_id_for_review_item(db, item)
        if item_source_book_id != source_book_id:
            continue
        if candidate_data.get("processing_stage") != body.processing_stage:
            continue

        if item.status != "pending":
            skipped_item_ids.append(item.id)
            continue

        try:
            await _apply_review_decision(
                db,
                item=item,
                action=ReviewAction.approve,
                correction=None,
                selected_candidate_id=None,
            )
        except HTTPException as exc:
            failed_items.append({"item_id": item.id, "error": str(exc.detail)})
        else:
            approved_item_ids.append(item.id)

    await db.commit()
    return ReviewBulkApprovalResponse(
        source_book_id=source_book_id,
        processing_stage=body.processing_stage,
        approved_count=len(approved_item_ids),
        skipped_count=len(skipped_item_ids),
        failed_count=len(failed_items),
        approved_item_ids=approved_item_ids,
        skipped_item_ids=skipped_item_ids,
        failed_items=failed_items,
    )


async def _source_book_id_for_review_item(
    db: AsyncSession,
    item: ReviewItem,
) -> str | None:
    candidate_data = dict(item.candidate_data or {})
    source_book_id = candidate_data.get("source_book_id")
    if isinstance(source_book_id, str) and source_book_id.strip():
        return source_book_id.strip()

    source_review_item_id = candidate_data.get("source_review_item_id")
    if not isinstance(source_review_item_id, str) or not source_review_item_id.strip():
        return None
    source_item = await db.get(ReviewItem, source_review_item_id.strip())
    if not source_item:
        return None
    source_candidate_data = dict(source_item.candidate_data or {})
    source_book_id = source_candidate_data.get("source_book_id")
    if isinstance(source_book_id, str) and source_book_id.strip():
        return source_book_id.strip()
    return None


@router.post("/{item_id}")
async def submit_review(
    item_id: str,
    body: ReviewItemRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Approve or reject a review item."""
    item = await db.get(ReviewItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Review item not found")

    await _apply_review_decision(
        db,
        item=item,
        action=body.action,
        correction=body.correction,
        selected_candidate_id=body.selected_candidate_id,
    )
    await db.commit()
    await db.refresh(item)
    return _review_item_to_response(request, item)


async def _apply_review_decision(
    db: AsyncSession,
    *,
    item: ReviewItem,
    action: object,
    correction: dict | None,
    selected_candidate_id: str | None,
) -> None:
    action_value = getattr(action, "value", action)
    if item.status != "pending":
        raise HTTPException(status_code=409, detail="Review item already resolved")

    candidate_data = dict(item.candidate_data or {})
    raw_score_id = candidate_data.get("raw_score_version_id")
    rendered_score_id = candidate_data.get("score_version_id")
    canonical_score_id = candidate_data.get("canonical_score_version_id")

    if action_value == ReviewAction.approve.value:
        if candidate_data.get("processing_stage") in {
            "metadata_review_needed",
            "split_review_needed",
        }:
            await _approve_student_pdf_review(
                db,
                item=item,
                candidate_data=candidate_data,
                correction=correction,
            )
            return

        piece = await db.get(Piece, item.piece_id)
        if item.item_type == ReviewItemType.score_candidate:
            candidate_data = _select_omr_candidate(
                candidate_data,
                selected_candidate_id=selected_candidate_id,
            )
            raw_score_id = candidate_data.get("raw_score_version_id")
            rendered_score_id = candidate_data.get("score_version_id")
            canonical_score_id = candidate_data.get("canonical_score_version_id")
        authoritative_metadata = (
            _authoritative_catalog_metadata(piece, candidate_data) if piece else {}
        )
        candidate_data = _apply_review_correction(
            candidate_data,
            correction,
            fallback_metadata=authoritative_metadata,
        )
        item.candidate_data = candidate_data
        if piece:
            if item.item_type == ReviewItemType.score_candidate and correction:
                try:
                    candidate_data = await _refresh_candidate_output_for_metadata(
                        db,
                        piece=piece,
                        candidate_data=candidate_data,
                    )
                    item.candidate_data = candidate_data
                except ProcessingEngineError as exc:
                    raise HTTPException(status_code=409, detail=str(exc)) from exc
        if (
            item.item_type == ReviewItemType.score_candidate
            and rendered_score_id
            and not _candidate_render_is_valid(candidate_data)
        ):
            raise HTTPException(
                status_code=409,
                detail=(
                    _candidate_render_validation_error(candidate_data)
                    or "Rendered review PDF is not valid yet. Rerender the MusicXML "
                    "candidate before approval."
                ),
            )

        item.status = "approved"
        item.candidate_data = candidate_data
        if piece:
            _apply_catalog_metadata_to_piece(piece, candidate_data)

        rendered_version = None
        raw_version = None
        canonical_version = None

        if item.item_type == ReviewItemType.score_candidate and rendered_score_id:
            result = await db.execute(
                select(ScoreVersion).where(ScoreVersion.id == rendered_score_id)
            )
            rendered_version = result.scalar_one_or_none()
            if rendered_version:
                await db.execute(
                    update(ScoreVersion)
                    .where(ScoreVersion.piece_id == item.piece_id)
                    .values(is_default=False)
                )
                rendered_version.is_default = True
                rendered_version.version_type = ScoreVersionType.approved
                _piece_state_service.set_score_version_metadata(
                    item.piece_id,
                    rendered_version.id,
                    artifact_role="human_approved_render_pdf",
                    student_default=True,
                    approved_by_parent=True,
                    display_rank=5,
                )
        elif item.item_type == ReviewItemType.score_candidate and raw_score_id:
            result = await db.execute(select(ScoreVersion).where(ScoreVersion.id == raw_score_id))
            raw_version = result.scalar_one_or_none()
            if raw_version:
                raw_version.is_default = True
                raw_version.version_type = ScoreVersionType.approved
                _piece_state_service.set_score_version_metadata(
                    item.piece_id,
                    raw_version.id,
                    artifact_role="original_import",
                    student_default=True,
                    approved_by_parent=True,
                    display_rank=10,
                )

        if canonical_score_id:
            result = await db.execute(
                select(ScoreVersion).where(ScoreVersion.id == canonical_score_id)
            )
            canonical_version = result.scalar_one_or_none()
            if canonical_version:
                canonical_version.version_type = ScoreVersionType.approved
                _piece_state_service.set_score_version_metadata(
                    item.piece_id,
                    canonical_version.id,
                    artifact_role="human_approved_musicxml",
                    student_default=False,
                    approved_by_parent=True,
                    display_rank=50,
                )

        if item.item_type == ReviewItemType.score_candidate and rendered_version:
            if not piece or not canonical_version or not raw_score_id:
                raise HTTPException(
                    status_code=409,
                    detail="Notation approval requires original, baseline, and rendered files.",
                )
            raw_result = await db.execute(
                select(ScoreVersion).where(
                    ScoreVersion.id == raw_score_id,
                    ScoreVersion.piece_id == item.piece_id,
                )
            )
            raw_version = raw_result.scalar_one_or_none()
            if not raw_version:
                raise HTTPException(
                    status_code=409,
                    detail="Notation approval requires the original source file.",
                )
            try:
                training_sample = catalog_notation_training_sample(
                    piece=piece,
                    review_item=item,
                    candidate_data=candidate_data,
                    raw_score_version=raw_version,
                    canonical_score_version=canonical_version,
                    rendered_score_version=rendered_version,
                    piece_state_service=_piece_state_service,
                )
            except TrainingCatalogError as exc:
                raise HTTPException(status_code=409, detail=str(exc)) from exc
            candidate_data = {
                **candidate_data,
                "training_sample_id": training_sample["sample_id"],
                "training_cataloged_at": training_sample["created_at"],
                "human_approved_for_training": True,
            }
            item.candidate_data = candidate_data

        pending_result = await db.execute(
            select(ReviewItem).where(
                ReviewItem.piece_id == item.piece_id,
                ReviewItem.status == "pending",
                ReviewItem.id != item.id,
            )
        )
        if pending_result.scalar_one_or_none() is None:
            if piece:
                piece.status = PieceStatus.approved
                await supersede_duplicate_pending_reviews(
                    db,
                    canonical_piece_id=piece.id,
                    resolved_review_item_id=item.id,
                )
                # Trigger YouTube reference search after full approval
                _trigger_media_search_async(piece)
        await _mark_source_book_ready_if_metadata_review_complete(db, item=item)

    elif action_value == ReviewAction.reject.value:
        item.status = "rejected"
        candidate_data["rejected_at"] = datetime.utcnow().isoformat()
        candidate_data["needs_edits"] = True
        candidate_data["future_llm_fix_available"] = False
        item.candidate_data = candidate_data

        for score_version_id in _candidate_score_version_ids(candidate_data):
            if not score_version_id:
                continue
            result = await db.execute(
                select(ScoreVersion).where(ScoreVersion.id == score_version_id)
            )
            score_version = result.scalar_one_or_none()
            if score_version:
                score_version.version_type = ScoreVersionType.rejected

        pending_result = await db.execute(
            select(ReviewItem).where(
                ReviewItem.piece_id == item.piece_id,
                ReviewItem.status == "pending",
                ReviewItem.id != item.id,
            )
        )
        if pending_result.scalar_one_or_none() is None:
            piece = await db.get(Piece, item.piece_id)
            if piece:
                piece.status = PieceStatus.needs_edits
                piece.updated_at = datetime.utcnow()
        await _mark_source_book_ready_if_metadata_review_complete(db, item=item)
    else:
        raise HTTPException(status_code=400, detail="Unsupported review action.")


async def _approve_student_pdf_review(
    db: AsyncSession,
    *,
    item: ReviewItem,
    candidate_data: dict,
    correction: dict | None,
) -> None:
    """Approve the PDF-first metadata review and make the cleaned score student-ready."""
    candidate_data = _apply_review_correction(candidate_data, correction)
    candidate_data["student_artifact_approved"] = True
    candidate_data["approved_student_artifact"] = (
        candidate_data.get("student_artifact") or "cleaned_pdf"
    )
    item.status = "approved"
    item.candidate_data = candidate_data

    piece = await db.get(Piece, item.piece_id)
    if piece:
        _apply_catalog_metadata_to_piece(piece, candidate_data)
        piece.status = PieceStatus.approved
        piece.updated_at = datetime.utcnow()
        # Trigger YouTube reference search after full approval
        _trigger_media_search_async(piece)

    raw_score_id = candidate_data.get("raw_score_version_id")
    cleaned_score_id = (
        candidate_data.get("cleaned_score_version_id")
        or candidate_data.get("student_default_score_version_id")
        or candidate_data.get("score_version_id")
        or raw_score_id
    )
    if isinstance(raw_score_id, str) and raw_score_id.strip():
        _piece_state_service.set_score_version_metadata(
            item.piece_id,
            raw_score_id.strip(),
            artifact_role="original_import",
            student_default=False,
            approved_by_parent=True,
            display_rank=100,
        )
    if isinstance(cleaned_score_id, str) and cleaned_score_id.strip():
        result = await db.execute(
            select(ScoreVersion).where(
                ScoreVersion.id == cleaned_score_id.strip(),
                ScoreVersion.piece_id == item.piece_id,
            )
        )
        cleaned_version = result.scalar_one_or_none()
        if cleaned_version:
            await db.execute(
                update(ScoreVersion)
                .where(ScoreVersion.piece_id == item.piece_id)
                .values(is_default=False)
            )
            cleaned_version.is_default = True
            cleaned_version.version_type = ScoreVersionType.approved
            _piece_state_service.set_score_version_metadata(
                item.piece_id,
                cleaned_version.id,
                artifact_role="cleaned_pdf",
                replaces_score_version_id=raw_score_id if isinstance(raw_score_id, str) else None,
                student_default=True,
                approved_by_parent=True,
                display_rank=10,
            )

    if piece:
        await supersede_duplicate_pending_reviews(
            db,
            canonical_piece_id=piece.id,
            resolved_review_item_id=item.id,
        )
    await _mark_source_book_ready_if_metadata_review_complete(db, item=item)


async def _mark_source_book_ready_if_metadata_review_complete(
    db: AsyncSession,
    *,
    item: ReviewItem,
) -> None:
    """Make the preserved book PDF pushable only after child metadata review finishes."""
    source_book_id = await _source_book_id_for_review_item(db, item)
    if not source_book_id:
        return

    source_book = await db.get(Piece, source_book_id)
    if not source_book:
        return
    source_metadata = _piece_state_service.metadata_for_piece(source_book)
    if source_metadata["piece_kind"] != "book" or source_book.status == PieceStatus.archived:
        return

    child_result = await db.execute(select(Piece))
    has_child_piece = False
    for child_piece in child_result.scalars().all():
        if child_piece.id == source_book_id:
            continue
        child_metadata = _piece_state_service.metadata_for_piece(child_piece)
        if child_metadata["source_book_id"] == source_book_id:
            has_child_piece = True
            break
    if not has_child_piece:
        return

    review_result = await db.execute(select(ReviewItem))
    for review_item in review_result.scalars().all():
        if review_item.status != "pending":
            continue
        candidate_data = dict(review_item.candidate_data or {})
        if candidate_data.get("processing_stage") not in _METADATA_REVIEW_STAGES:
            continue
        review_source_book_id = await _source_book_id_for_review_item(db, review_item)
        if review_source_book_id == source_book_id:
            return

    source_book.status = PieceStatus.approved
    source_book.updated_at = datetime.utcnow()

    raw_result = await db.execute(
        select(ScoreVersion)
        .where(
            ScoreVersion.piece_id == source_book_id,
            ScoreVersion.version_type == ScoreVersionType.raw,
        )
        .limit(1)
    )
    raw_version = raw_result.scalar_one_or_none()
    if raw_version:
        raw_version.is_default = False
        _piece_state_service.set_score_version_metadata(
            source_book_id,
            raw_version.id,
            artifact_role="original_import",
            approved_by_parent=True,
            student_default=False,
            display_rank=100,
        )

    cleaned_result = await db.execute(
        select(ScoreVersion).where(ScoreVersion.piece_id == source_book_id)
    )
    for score_version in cleaned_result.scalars().all():
        workflow_metadata = _piece_state_service.score_version_metadata(
            source_book_id,
            score_version.id,
        )
        if workflow_metadata.get("artifact_role") != "cleaned_pdf":
            continue
        score_version.is_default = True
        score_version.version_type = ScoreVersionType.approved
        _piece_state_service.set_score_version_metadata(
            source_book_id,
            score_version.id,
            artifact_role="cleaned_pdf",
            replaces_score_version_id=raw_version.id if raw_version else None,
            approved_by_parent=True,
            student_default=True,
            display_rank=10,
        )
        break

    if source_metadata["visible_to_profile_ids"]:
        child_result = await db.execute(select(Piece))
        for child_piece in child_result.scalars().all():
            if child_piece.id == source_book_id or child_piece.status != PieceStatus.approved:
                continue
            child_metadata = _piece_state_service.metadata_for_piece(child_piece)
            if child_metadata["source_book_id"] != source_book_id:
                continue
            _piece_state_service.assign_profiles(
                child_piece.id,
                list(source_metadata["visible_to_profile_ids"]),
            )
            child_piece.updated_at = datetime.utcnow()


@router.post("/{item_id}/reprocess", response_model=JobResponse)
async def request_review_reprocess(
    item_id: str,
    body: ReviewReprocessRequest,
    db: AsyncSession = Depends(get_db),
):
    """Request local-LLM-assisted follow-up processing for a review item."""
    item = await db.get(ReviewItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Review item not found")
    if body.reprocess_type.value != "score":
        raise HTTPException(
            status_code=410,
            detail=(
                "Metadata LLM review has been removed. Edit metadata directly "
                "in the parent review workflow."
            ),
        )

    now = datetime.utcnow()
    job = BackgroundJob(
        id=str(uuid.uuid4()),
        piece_id=item.piece_id,
        job_type=f"review_{body.reprocess_type.value}_reprocess",
        status=JobStatus.running,
        progress=10.0,
        created_at=now,
        updated_at=now,
        result_data={
            "review_item_id": item.id,
            "reprocess_type": body.reprocess_type.value,
        },
    )
    db.add(job)
    await db.flush()

    candidate_data = dict(item.candidate_data or {})
    if body.reprocess_type.value == "score":
        try:
            candidate_data = await _run_local_llm_score_reprocess(
                db,
                item=item,
                job=job,
                candidate_data=candidate_data,
                parent_notes=body.parent_notes,
            )
            item.candidate_data = candidate_data
            job.status = JobStatus.succeeded
            job.progress = 100.0
            job.updated_at = datetime.utcnow()
            _processing_settings_store.record_last_llm_error(None)
        except (
            LocalLlmUnavailableError,
            ScoreMcpToolError,
            ScoreVisualDiffError,
            ProcessingEngineError,
            OSError,
        ) as exc:
            message = str(exc)
            job.status = JobStatus.failed
            job.progress = 100.0
            job.error_message = message
            job.result_data = {
                **(job.result_data or {}),
                "local_llm_available": False,
                "warnings": [message],
            }
            job.updated_at = datetime.utcnow()
            _processing_settings_store.record_last_llm_error(message)
            candidate_data = _append_reprocess_warning(
                candidate_data,
                reprocess_type=body.reprocess_type.value,
                warning=message,
                parent_notes=body.parent_notes,
            )
            item.candidate_data = candidate_data
        await db.commit()
        await db.refresh(job)
        return JobResponse(
            id=job.id,
            piece_id=job.piece_id,
            job_type=job.job_type,
            status=job.status,
            progress=job.progress,
            error_message=job.error_message,
            result_data=job.result_data,
            created_at=job.created_at,
            updated_at=job.updated_at,
        )


@router.post("/{item_id}/llm-correction-json", response_model=JobResponse)
async def request_llm_correction_json(
    item_id: str,
    body: ReviewReprocessRequest,
    db: AsyncSession = Depends(get_db),
):
    """Run the structured Correction JSON path for a notation candidate."""
    item = await db.get(ReviewItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Review item not found")
    if body.reprocess_type.value != "score":
        raise HTTPException(
            status_code=400,
            detail="Correction JSON is only available for score review.",
        )

    now = datetime.utcnow()
    job = BackgroundJob(
        id=str(uuid.uuid4()),
        piece_id=item.piece_id,
        job_type="llm_correction_json",
        status=JobStatus.running,
        progress=10.0,
        created_at=now,
        updated_at=now,
        result_data={
            "review_item_id": item.id,
            "target_output": "correction_json",
            "reprocess_type": "score",
        },
    )
    db.add(job)
    await db.flush()

    candidate_data = dict(item.candidate_data or {})
    try:
        candidate_data = await _run_local_llm_score_reprocess(
            db,
            item=item,
            job=job,
            candidate_data=candidate_data,
            parent_notes=body.parent_notes,
        )
        session = {
            "id": job.id,
            "created_at": datetime.utcnow().isoformat(),
            "target_output": "correction_json",
            "parent_notes": body.parent_notes,
            "status": "candidate_created",
            "applied_tool_results": candidate_data.get("local_llm_tool_results", []),
            "findings": candidate_data.get("local_llm_findings", []),
            "corrected_score_version_id": candidate_data.get("score_version_id"),
            "corrected_canonical_score_version_id": candidate_data.get(
                "canonical_score_version_id"
            ),
        }
        sessions = list(candidate_data.get("correction_json_sessions") or [])
        sessions.append(session)
        candidate_data["correction_json_sessions"] = sessions
        item.candidate_data = candidate_data
        job.status = JobStatus.succeeded
        job.progress = 100.0
        job.result_data = {
            **(job.result_data or {}),
            "correction_json_session": session,
        }
        job.updated_at = datetime.utcnow()
        _processing_settings_store.record_last_llm_error(None)
    except (
        LocalLlmUnavailableError,
        ScoreMcpToolError,
        ScoreVisualDiffError,
        ProcessingEngineError,
        OSError,
    ) as exc:
        message = str(exc)
        job.status = JobStatus.failed
        job.progress = 100.0
        job.error_message = message
        job.result_data = {
            **(job.result_data or {}),
            "target_output": "correction_json",
            "warnings": [message],
        }
        job.updated_at = datetime.utcnow()
        _processing_settings_store.record_last_llm_error(message)
        item.candidate_data = _append_reprocess_warning(
            candidate_data,
            reprocess_type="score",
            warning=message,
            parent_notes=body.parent_notes,
        )

    await db.commit()
    await db.refresh(job)
    return JobResponse(
        id=job.id,
        piece_id=job.piece_id,
        job_type=job.job_type,
        status=job.status,
        progress=job.progress,
        error_message=job.error_message,
        result_data=job.result_data,
        created_at=job.created_at,
        updated_at=job.updated_at,
    )


async def _run_local_llm_score_reprocess(
    db: AsyncSession,
    *,
    item: ReviewItem,
    job: BackgroundJob,
    candidate_data: dict,
    parent_notes: str | None,
) -> dict:
    settings_payload = _processing_settings_store.load()
    provider = LocalLlmProvider(settings_payload)
    status = provider.status()
    if not status.configured:
        raise LocalLlmUnavailableError("Local LLM provider is not configured.")
    if not status.available:
        raise LocalLlmUnavailableError(
            status.error
            or "Local LLM is configured but is not reachable. Start the local LLM server."
        )
    raw_version, rendered_version, canonical_version = await _score_versions_for_review(
        db,
        candidate_data,
        provider_label="Local LLM check",
        error_factory=LocalLlmUnavailableError,
    )
    raw_path = Path(raw_version.file_path)
    rendered_path = Path(rendered_version.file_path)
    canonical_path = Path(canonical_version.file_path)
    for label, path in (
        ("original score", raw_path),
        ("rendered candidate PDF", rendered_path),
        ("MusicXML candidate", canonical_path),
    ):
        if not path.exists():
            raise LocalLlmUnavailableError(f"Local LLM check cannot find the {label}: {path}")

    job.progress = 25.0
    job.updated_at = datetime.utcnow()
    await db.flush()

    llm_result = provider.review_score(
        raw_pdf_path=raw_path,
        rendered_pdf_path=rendered_path,
        canonical_musicxml_path=canonical_path,
        candidate_data=candidate_data,
        parent_notes=parent_notes,
    )

    job.progress = 55.0
    job.updated_at = datetime.utcnow()
    await db.flush()

    workspace = canonical_path.parent / "local-llm-review" / job.id
    verification = _run_verified_local_llm_score_edits(
        provider=provider,
        settings_payload=settings_payload,
        raw_path=raw_path,
        rendered_path=rendered_path,
        canonical_path=canonical_path,
        candidate_data=candidate_data,
        parent_notes=parent_notes,
        llm_result=llm_result,
        workspace=workspace,
    )
    tool_results = verification["tool_results"]
    measure_reviews = verification["measure_reviews"]
    retry_attempted = bool(verification["retry_attempted"])
    if not verification["accepted_tool_results"]:
        status_value = _local_llm_no_candidate_status(
            tool_results=tool_results,
            llm_result=llm_result,
        )
        quality_loop = build_quality_loop_summary(
            outcome=(
                "metadata_or_layout_only"
                if status_value == "metadata_or_layout_only"
                else "hybrid_fallback"
            ),
            measure_reviews=measure_reviews,
            visual_diff=verification.get("visual_diff"),
        )
        if status_value != "metadata_or_layout_only":
            candidate_data = _attach_local_llm_hybrid_fallback_candidate(
                candidate_data,
                raw_score_version_id=raw_version.id,
                rendered_score_version_id=rendered_version.id,
                canonical_score_version_id=canonical_version.id,
                llm_result=llm_result,
                measure_reviews=measure_reviews,
                visual_diff=verification.get("visual_diff"),
                job_id=job.id,
            )
        return _record_local_llm_score_status(
            candidate_data,
            job=job,
            llm_result=llm_result,
            status=status_value,
            parent_notes=parent_notes,
            tool_results=tool_results,
            visual_diff=verification.get("visual_diff"),
            measure_reviews=measure_reviews,
            quality_loop=quality_loop,
            retry_attempted=retry_attempted,
        )

    job.progress = 72.0
    job.updated_at = datetime.utcnow()
    await db.flush()

    corrected_canonical_path = verification["canonical_path"]
    _validate_musicxml(corrected_canonical_path)
    corrected_rendered_path = verification["rendered_path"]
    render_result = verification["render_result"]
    visual_diff = compare_score_pdfs(
        before_pdf_path=rendered_path,
        after_pdf_path=corrected_rendered_path,
        original_pdf_path=raw_path,
    )
    if not visual_diff.get("passed"):
        quality_loop = build_quality_loop_summary(
            outcome="hybrid_fallback",
            measure_reviews=measure_reviews,
            visual_diff=visual_diff,
        )
        candidate_data = _attach_local_llm_hybrid_fallback_candidate(
            candidate_data,
            raw_score_version_id=raw_version.id,
            rendered_score_version_id=rendered_version.id,
            canonical_score_version_id=canonical_version.id,
            llm_result=llm_result,
            measure_reviews=measure_reviews,
            visual_diff=visual_diff,
            job_id=job.id,
        )
        return _record_local_llm_score_status(
            candidate_data,
            job=job,
            llm_result=llm_result,
            status="no_visible_notation_change",
            parent_notes=parent_notes,
            tool_results=tool_results,
            visual_diff=visual_diff,
            render_warnings=render_result.warnings,
            measure_reviews=measure_reviews,
            quality_loop=quality_loop,
            retry_attempted=retry_attempted,
        )

    corrected_canonical_version = ScoreVersion(
        id=str(uuid.uuid4()),
        piece_id=item.piece_id,
        version_type=ScoreVersionType.reconstructed_candidate,
        file_path=str(corrected_canonical_path),
        is_default=False,
        created_at=datetime.utcnow(),
    )
    corrected_rendered_version = ScoreVersion(
        id=str(uuid.uuid4()),
        piece_id=item.piece_id,
        version_type=ScoreVersionType.reconstructed_candidate,
        file_path=str(corrected_rendered_path),
        is_default=False,
        created_at=datetime.utcnow(),
    )
    db.add(corrected_canonical_version)
    db.add(corrected_rendered_version)
    await db.flush()

    candidate_id = f"local_llm_{job.id[:8]}"
    tool_result_payload = _score_tool_results_payload(tool_results)
    llm_candidate = {
        "candidate_id": candidate_id,
        "label": "Local LLM notation correction",
        "engine_name": "local_llm",
        "engine_version": llm_result.model,
        "provenance": "local_llm_vision_mcp",
        "confidence": llm_result.confidence,
        "raw_score_version_id": raw_version.id,
        "canonical_score_version_id": corrected_canonical_version.id,
        "score_version_id": corrected_rendered_version.id,
        "renderer_name": render_result.renderer_name,
        "renderer_version": render_result.renderer_version,
        "renderer_provenance": render_result.provenance,
        "render_validation_status": render_result.validation_status,
        "render_validation_error": render_result.validation_error,
        "rendered_file_size_bytes": render_result.file_size_bytes,
        "rendered_page_count": render_result.page_count,
        "render_diagnostics": render_result.diagnostics,
        "llm_notation_review_status": "notation_corrected",
        "llm_notation_findings": list(llm_result.notation_findings or []),
        "llm_tool_results": tool_result_payload,
        "llm_measure_reviews": measure_reviews,
        "llm_verification_status": "verified_correction",
        "llm_visual_diff": visual_diff,
        "llm_correction_scope": "notation",
        "llm_vision_model_hint": llm_result.vision_model_hint,
        "llm_model_auto_selected": llm_result.model_auto_selected,
        "warnings": list(llm_result.warnings or []) + render_result.warnings,
        "selected": True,
    }

    previous_candidates = [
        {**candidate, "selected": False}
        for candidate in candidate_data.get("omr_candidates") or []
        if isinstance(candidate, dict)
    ]
    candidate_data["omr_candidates"] = [llm_candidate, *previous_candidates]
    for key, value in llm_candidate.items():
        if key not in {"candidate_id", "label", "warnings", "selected"}:
            candidate_data[key] = value
    candidate_data["selected_omr_candidate_id"] = candidate_id
    candidate_data["selected_omr_candidate_label"] = llm_candidate["label"]
    quality_loop = build_quality_loop_summary(
        outcome="verified_musicxml",
        measure_reviews=measure_reviews,
        visual_diff=visual_diff,
    )
    return _record_local_llm_score_status(
        candidate_data,
        job=job,
        llm_result=llm_result,
        status="notation_corrected",
        parent_notes=parent_notes,
        tool_results=tool_results,
        visual_diff=visual_diff,
        render_warnings=render_result.warnings,
        measure_reviews=measure_reviews,
        quality_loop=quality_loop,
        selected_candidate_id=candidate_id,
        corrected_canonical_score_version_id=corrected_canonical_version.id,
        corrected_rendered_score_version_id=corrected_rendered_version.id,
        retry_attempted=retry_attempted,
    )


def _run_verified_local_llm_score_edits(
    *,
    provider,
    settings_payload: dict,
    raw_path: Path,
    rendered_path: Path,
    canonical_path: Path,
    candidate_data: dict,
    parent_notes: str | None,
    llm_result,
    workspace: Path,
) -> dict:
    workspace.mkdir(parents=True, exist_ok=True)
    current_canonical_path = canonical_path
    current_rendered_path = rendered_path
    current_render_result = None
    final_visual_diff = None
    tool_results: list[ScoreMcpToolResult] = []
    accepted_tool_results: list[ScoreMcpToolResult] = []
    measure_reviews: list[dict] = []
    retry_attempted = False

    for tool_index, proposed_tool_call in enumerate(llm_result.tool_calls or [], start=1):
        if not isinstance(proposed_tool_call, dict):
            result = ScoreMcpToolResult(
                name="<malformed>",
                status="failed",
                message="The LLM returned a malformed tool call.",
                structured_content={"affects_notation": False},
                affects_notation=False,
            )
            tool_results.append(result)
            measure_reviews.append(
                _local_llm_measure_review_entry(
                    tool_index=tool_index,
                    attempt_index=1,
                    status="rejected",
                    reason=result.message,
                    tool_call={},
                    tool_result=result,
                    target_finding=None,
                )
            )
            continue

        target_finding = _matching_local_llm_notation_finding(
            proposed_tool_call,
            llm_result.notation_findings or [],
        )
        tool_call = proposed_tool_call
        attempt_index = 1
        while attempt_index <= _LOCAL_LLM_MAX_ATTEMPTS_PER_TOOL:
            attempt_workspace = workspace / f"tool-{tool_index:02d}-attempt-{attempt_index:02d}"
            name = _score_tool_call_name(tool_call)

            if name == "replace_musicxml_text":
                result, _ = _apply_local_llm_score_tool(
                    source_musicxml_path=current_canonical_path,
                    workspace_path=attempt_workspace,
                    tool_call=tool_call,
                )
                tool_results.append(result)
                if result.status == "succeeded" and not result.affects_notation:
                    measure_reviews.append(
                        _local_llm_measure_review_entry(
                            tool_index=tool_index,
                            attempt_index=attempt_index,
                            status="metadata_or_layout_only",
                            reason=(
                                "The edit did not affect notation and was recorded "
                                "only as review output."
                            ),
                            tool_call=tool_call,
                            tool_result=result,
                            target_finding=target_finding,
                        )
                    )
                    break

                rejection_reason = (
                    "replace_musicxml_text is not allowed to publish notation changes; "
                    "use a bounded structured notation tool instead."
                )
                measure_reviews.append(
                    _local_llm_measure_review_entry(
                        tool_index=tool_index,
                        attempt_index=attempt_index,
                        status="rejected",
                        reason=rejection_reason,
                        tool_call=tool_call,
                        tool_result=result,
                        target_finding=target_finding,
                    )
                )
                retry_tool_call = _retry_local_llm_score_tool_call(
                    provider=provider,
                    raw_path=raw_path,
                    rendered_path=current_rendered_path,
                    canonical_path=current_canonical_path,
                    candidate_data=candidate_data,
                    parent_notes=parent_notes,
                    llm_result=llm_result,
                    target_finding=target_finding,
                    failed_tool_call=tool_call,
                    failed_tool_result=result,
                    rejection_reason=rejection_reason,
                    attempt_index=attempt_index,
                    measure_reviews=measure_reviews,
                )
                if retry_tool_call is None:
                    break
                retry_attempted = True
                tool_call = retry_tool_call
                attempt_index += 1
                continue

            safety_error = _local_llm_small_score_tool_safety_error(tool_call)
            if safety_error:
                result = ScoreMcpToolResult(
                    name=name or "<unknown>",
                    status="failed",
                    message=safety_error,
                    structured_content={
                        "arguments": _score_tool_call_arguments(tool_call),
                        "affects_notation": False,
                    },
                    affects_notation=False,
                )
                tool_results.append(result)
                measure_reviews.append(
                    _local_llm_measure_review_entry(
                        tool_index=tool_index,
                        attempt_index=attempt_index,
                        status="rejected",
                        reason=safety_error,
                        tool_call=tool_call,
                        tool_result=result,
                        target_finding=target_finding,
                    )
                )
                retry_tool_call = _retry_local_llm_score_tool_call(
                    provider=provider,
                    raw_path=raw_path,
                    rendered_path=current_rendered_path,
                    canonical_path=current_canonical_path,
                    candidate_data=candidate_data,
                    parent_notes=parent_notes,
                    llm_result=llm_result,
                    target_finding=target_finding,
                    failed_tool_call=tool_call,
                    failed_tool_result=result,
                    rejection_reason=safety_error,
                    attempt_index=attempt_index,
                    measure_reviews=measure_reviews,
                )
                if retry_tool_call is None:
                    break
                retry_attempted = True
                tool_call = retry_tool_call
                attempt_index += 1
                continue

            result, edited_musicxml_path = _apply_local_llm_score_tool(
                source_musicxml_path=current_canonical_path,
                workspace_path=attempt_workspace,
                tool_call=tool_call,
            )
            tool_results.append(result)
            if result.status != "succeeded" or not result.affects_notation:
                reason = result.message or "The tool did not produce a notation edit."
                measure_reviews.append(
                    _local_llm_measure_review_entry(
                        tool_index=tool_index,
                        attempt_index=attempt_index,
                        status="rejected",
                        reason=reason,
                        tool_call=tool_call,
                        tool_result=result,
                        target_finding=target_finding,
                    )
                )
                retry_tool_call = _retry_local_llm_score_tool_call(
                    provider=provider,
                    raw_path=raw_path,
                    rendered_path=current_rendered_path,
                    canonical_path=current_canonical_path,
                    candidate_data=candidate_data,
                    parent_notes=parent_notes,
                    llm_result=llm_result,
                    target_finding=target_finding,
                    failed_tool_call=tool_call,
                    failed_tool_result=result,
                    rejection_reason=reason,
                    attempt_index=attempt_index,
                    measure_reviews=measure_reviews,
                )
                if retry_tool_call is None:
                    break
                retry_attempted = True
                tool_call = retry_tool_call
                attempt_index += 1
                continue

            attempt_rendered_path = attempt_workspace / "candidate.pdf"
            try:
                render_result = MuseScoreRenderEngine().render(
                    canonical_path=edited_musicxml_path,
                    raw_pdf_path=raw_path,
                    output_pdf_path=attempt_rendered_path,
                    processing_settings=settings_payload,
                )
                visual_diff = compare_score_pdfs(
                    before_pdf_path=current_rendered_path,
                    after_pdf_path=attempt_rendered_path,
                    original_pdf_path=raw_path,
                )
            except (ProcessingEngineError, ScoreVisualDiffError) as exc:
                reason = f"The edited candidate could not be rendered or compared: {exc}"
                measure_reviews.append(
                    _local_llm_measure_review_entry(
                        tool_index=tool_index,
                        attempt_index=attempt_index,
                        status="rejected",
                        reason=reason,
                        tool_call=tool_call,
                        tool_result=result,
                        target_finding=target_finding,
                    )
                )
                retry_tool_call = _retry_local_llm_score_tool_call(
                    provider=provider,
                    raw_path=raw_path,
                    rendered_path=current_rendered_path,
                    canonical_path=current_canonical_path,
                    candidate_data=candidate_data,
                    parent_notes=parent_notes,
                    llm_result=llm_result,
                    target_finding=target_finding,
                    failed_tool_call=tool_call,
                    failed_tool_result=result,
                    rejection_reason=reason,
                    attempt_index=attempt_index,
                    measure_reviews=measure_reviews,
                )
                if retry_tool_call is None:
                    break
                retry_attempted = True
                tool_call = retry_tool_call
                attempt_index += 1
                continue

            final_visual_diff = visual_diff
            verification = _verify_local_llm_score_edit(
                provider=provider,
                raw_path=raw_path,
                before_rendered_path=current_rendered_path,
                after_rendered_path=attempt_rendered_path,
                candidate_data=candidate_data,
                parent_notes=parent_notes,
                target_finding=target_finding,
                tool_call=tool_call,
                tool_result=result,
                visual_diff=visual_diff,
            )
            accepted, reason = _local_llm_score_edit_is_accepted(
                visual_diff=visual_diff,
                verification=verification,
            )
            measure_reviews.append(
                _local_llm_measure_review_entry(
                    tool_index=tool_index,
                    attempt_index=attempt_index,
                    status="accepted" if accepted else "rejected",
                    reason=reason,
                    tool_call=tool_call,
                    tool_result=result,
                    target_finding=target_finding,
                    visual_diff=visual_diff,
                    verification=verification,
                )
            )
            if accepted:
                accepted_tool_results.append(result)
                current_canonical_path = edited_musicxml_path
                current_rendered_path = attempt_rendered_path
                current_render_result = render_result
                break

            retry_tool_call = _retry_local_llm_score_tool_call(
                provider=provider,
                raw_path=raw_path,
                rendered_path=current_rendered_path,
                canonical_path=current_canonical_path,
                candidate_data=candidate_data,
                parent_notes=parent_notes,
                llm_result=llm_result,
                target_finding=target_finding,
                failed_tool_call=tool_call,
                failed_tool_result=result,
                rejection_reason=reason,
                attempt_index=attempt_index,
                measure_reviews=measure_reviews,
                visual_diff=visual_diff,
                verification=verification,
            )
            if retry_tool_call is None:
                break
            retry_attempted = True
            tool_call = retry_tool_call
            attempt_index += 1

    return {
        "tool_results": tool_results,
        "accepted_tool_results": accepted_tool_results,
        "measure_reviews": measure_reviews,
        "retry_attempted": retry_attempted,
        "canonical_path": current_canonical_path,
        "rendered_path": current_rendered_path,
        "render_result": current_render_result,
        "visual_diff": final_visual_diff,
    }


def _apply_local_llm_score_tool(
    *,
    source_musicxml_path: Path,
    workspace_path: Path,
    tool_call: dict,
) -> tuple[ScoreMcpToolResult, Path]:
    name = _score_tool_call_name(tool_call)
    try:
        controller = ScoreMcpToolController(
            source_musicxml_path=source_musicxml_path,
            workspace_path=workspace_path,
        )
        result = controller.apply_tool_calls([tool_call])[0]
        return result, controller.working_musicxml_path
    except ScoreMcpToolError as exc:
        return (
            ScoreMcpToolResult(
                name=name or "<unknown>",
                status="failed",
                message=str(exc),
                structured_content={
                    "arguments": _score_tool_call_arguments(tool_call),
                    "affects_notation": False,
                },
                affects_notation=False,
            ),
            workspace_path / "candidate.musicxml",
        )


def _retry_local_llm_score_tool_call(
    *,
    provider,
    raw_path: Path,
    rendered_path: Path,
    canonical_path: Path,
    candidate_data: dict,
    parent_notes: str | None,
    llm_result,
    target_finding: dict | None,
    failed_tool_call: dict,
    failed_tool_result: ScoreMcpToolResult,
    rejection_reason: str,
    attempt_index: int,
    measure_reviews: list[dict],
    visual_diff: dict | None = None,
    verification: dict | None = None,
) -> dict | None:
    if attempt_index >= _LOCAL_LLM_MAX_ATTEMPTS_PER_TOOL:
        return None
    retry_count = sum(1 for review in measure_reviews if review.get("retry_generated"))
    if retry_count >= _LOCAL_LLM_MAX_ATTEMPTS_PER_TOOL:
        return None
    try:
        retry_result = provider.retry_score_correction(
            raw_pdf_path=raw_path,
            rendered_pdf_path=rendered_path,
            canonical_musicxml_path=canonical_path,
            candidate_data=candidate_data,
            parent_notes=parent_notes,
            audit_result={
                "summary": llm_result.audit_summary or llm_result.summary,
                "confidence": llm_result.confidence,
                "notation_findings": list(llm_result.notation_findings or []),
                "warnings": list(llm_result.warnings or []),
            },
            retry_context={
                "target_finding": target_finding or {},
                "rejected_tool_call": failed_tool_call,
                "rejected_tool_result": _score_tool_results_payload([failed_tool_result])[0],
                "rejection_reason": rejection_reason,
                "visual_diff": visual_diff,
                "verification": verification,
                "instruction": (
                    "Return one safer bounded structured notation tool call for the "
                    "same target, or return no tool calls if the target is uncertain."
                ),
            },
        )
    except LocalLlmUnavailableError as exc:
        if measure_reviews:
            measure_reviews[-1]["retry_error"] = str(exc)
        return None

    for tool_call in retry_result.tool_calls or []:
        if not isinstance(tool_call, dict):
            continue
        if measure_reviews:
            measure_reviews[-1]["retry_generated"] = True
            measure_reviews[-1]["retry_summary"] = retry_result.summary
        return tool_call
    if measure_reviews:
        measure_reviews[-1]["retry_summary"] = retry_result.summary
    return None


def _verify_local_llm_score_edit(
    *,
    provider,
    raw_path: Path,
    before_rendered_path: Path,
    after_rendered_path: Path,
    candidate_data: dict,
    parent_notes: str | None,
    target_finding: dict | None,
    tool_call: dict,
    tool_result: ScoreMcpToolResult,
    visual_diff: dict,
) -> dict:
    try:
        verification = provider.verify_score_edit(
            raw_pdf_path=raw_path,
            before_rendered_pdf_path=before_rendered_path,
            after_rendered_pdf_path=after_rendered_path,
            candidate_data=candidate_data,
            parent_notes=parent_notes,
            target_finding=target_finding,
            tool_call=tool_call,
            tool_result=_score_tool_results_payload([tool_result])[0],
            visual_diff=visual_diff,
        )
    except LocalLlmUnavailableError as exc:
        return {
            "accepted": False,
            "confidence": None,
            "summary": "Verification could not run.",
            "evidence": str(exc),
            "warnings": [str(exc)],
        }
    return {
        "accepted": bool(verification.accepted),
        "confidence": verification.confidence,
        "summary": verification.summary,
        "evidence": verification.evidence,
        "warnings": list(verification.warnings or []),
    }


def _local_llm_score_edit_is_accepted(
    *,
    visual_diff: dict,
    verification: dict,
) -> tuple[bool, str]:
    if not visual_diff.get("passed"):
        return False, "The rendered candidate did not visibly change."
    if verification.get("accepted") is not True:
        return False, verification.get("summary") or "The verifier rejected the edit."
    confidence = verification.get("confidence")
    try:
        confidence_value = float(confidence)
    except (TypeError, ValueError):
        return False, "The verifier did not provide a usable confidence score."
    if confidence_value < _LOCAL_LLM_EDIT_VERIFICATION_CONFIDENCE:
        return (
            False,
            (f"The verifier confidence was below {_LOCAL_LLM_EDIT_VERIFICATION_CONFIDENCE:.2f}."),
        )
    return True, verification.get("summary") or "The verifier accepted the edit."


def _local_llm_no_candidate_status(*, tool_results: list, llm_result) -> str:
    if any(
        result.status == "succeeded" and not bool(getattr(result, "affects_notation", False))
        for result in tool_results
    ):
        return "metadata_or_layout_only"
    if llm_result.notation_findings:
        return "finding_only"
    return "no_safe_notation_edit"


def _local_llm_small_score_tool_safety_error(tool_call: dict) -> str | None:
    name = _score_tool_call_name(tool_call)
    arguments = _score_tool_call_arguments(tool_call)
    if name not in _LOCAL_LLM_ALLOWED_SMALL_SCORE_TOOLS:
        return (
            f"Tool {name or '<unknown>'} is not allowed to publish notation changes. "
            "Use a bounded note, rest, measure, or direction tool."
        )
    if not isinstance(arguments, dict):
        return f"Tool {name} arguments were malformed."
    part_id = str(arguments.get("part_id") or "").strip()
    if not part_id:
        return f"Tool {name} requires part_id."
    physical_measure_index = _optional_positive_int(arguments.get("physical_measure_index"))
    measure_number = _optional_nonnegative_int(arguments.get("measure_number"))
    if physical_measure_index is None and measure_number is None:
        return f"Tool {name} requires physical_measure_index or measure_number."
    if name in {"update_note_pitch", "update_note_duration", "update_rest"}:
        if _optional_positive_int(arguments.get("note_index")) is None:
            return f"Tool {name} requires a positive note_index."
    if name == "update_note_pitch":
        step = str(arguments.get("step") or "").strip().upper()
        if step and step not in {"A", "B", "C", "D", "E", "F", "G"}:
            return "update_note_pitch step must be A through G."
        octave = _optional_int_value(arguments.get("octave"))
        if octave is not None and not 0 <= octave <= 8:
            return "update_note_pitch octave must be between 0 and 8."
        alter = _optional_int_value(arguments.get("alter"))
        if alter is not None and not -2 <= alter <= 2:
            return "update_note_pitch alter must be between -2 and 2."
    if name == "update_rest":
        display_step = str(arguments.get("display_step") or "").strip().upper()
        if display_step and display_step not in {"A", "B", "C", "D", "E", "F", "G"}:
            return "update_rest display_step must be A through G."
        display_octave = _optional_int_value(arguments.get("display_octave"))
        if display_octave is not None and not 0 <= display_octave <= 8:
            return "update_rest display_octave must be between 0 and 8."
    if name == "update_note_duration":
        duration = _optional_int_value(arguments.get("duration"))
        if duration is not None and duration <= 0:
            return "update_note_duration duration must be positive."
        dots = _optional_int_value(arguments.get("dots"))
        if dots is not None and not 0 <= dots <= 4:
            return "update_note_duration dots must be between 0 and 4."
    if name == "update_measure_time":
        if _optional_positive_int(arguments.get("beats")) is None:
            return "update_measure_time requires positive beats."
        if _optional_positive_int(arguments.get("beat_type")) is None:
            return "update_measure_time requires positive beat_type."
    if name == "update_measure_key":
        fifths = _optional_int_value(arguments.get("fifths"))
        if fifths is None:
            return "update_measure_key requires fifths."
        if not -7 <= fifths <= 7:
            return "update_measure_key fifths must be between -7 and 7."
    if name == "upsert_direction_words":
        text = str(arguments.get("text") or "").strip()
        if not text:
            return "upsert_direction_words requires text."
        if len(text) > 300:
            return "upsert_direction_words text is too long."
    return None


def _matching_local_llm_notation_finding(
    tool_call: dict,
    notation_findings: list[dict],
) -> dict | None:
    target = _score_tool_target_payload(tool_call)
    if not target:
        return None
    for finding in notation_findings:
        if not isinstance(finding, dict):
            continue
        if target.get("part_id") and finding.get("part_id") != target.get("part_id"):
            continue
        if target.get("staff") and finding.get("staff") not in (None, "", target.get("staff")):
            continue
        if target.get("voice") and finding.get("voice") not in (None, "", target.get("voice")):
            continue
        physical_index = target.get("physical_measure_index")
        if physical_index and finding.get("physical_measure_index") == physical_index:
            return finding
        measure_number = target.get("measure_number")
        if measure_number and finding.get("measure_number") == measure_number:
            note_index = target.get("note_index")
            if note_index in (None, 0) or finding.get("note_index") in (None, 0, note_index):
                return finding
    return None


def _local_llm_measure_review_entry(
    *,
    tool_index: int,
    attempt_index: int,
    status: str,
    reason: str,
    tool_call: dict,
    tool_result: ScoreMcpToolResult,
    target_finding: dict | None,
    visual_diff: dict | None = None,
    verification: dict | None = None,
) -> dict:
    return {
        "tool_index": tool_index,
        "attempt_index": attempt_index,
        "status": status,
        "reason": reason,
        "target": _score_tool_target_payload(tool_call),
        "target_finding": target_finding,
        "tool_call": {
            "name": _score_tool_call_name(tool_call),
            "arguments": _score_tool_call_arguments(tool_call),
        },
        "tool_result": _score_tool_results_payload([tool_result])[0],
        "visual_diff": visual_diff,
        "verification": verification,
    }


def _score_tool_call_name(tool_call: dict) -> str:
    return str(tool_call.get("name") or tool_call.get("tool") or "").strip()


def _score_tool_call_arguments(tool_call: dict) -> dict:
    arguments = tool_call.get("arguments") or {}
    return arguments if isinstance(arguments, dict) else {}


def _score_tool_target_payload(tool_call: dict) -> dict:
    arguments = _score_tool_call_arguments(tool_call)
    target = {
        "part_id": str(arguments.get("part_id") or "").strip(),
        "staff": str(arguments.get("staff") or "").strip(),
        "voice": str(arguments.get("voice") or "").strip(),
        "physical_measure_index": _optional_positive_int(arguments.get("physical_measure_index")),
        "measure_number": _optional_nonnegative_int(arguments.get("measure_number")),
        "note_index": _optional_positive_int(arguments.get("note_index")),
    }
    return {key: value for key, value in target.items() if value not in (None, "")}


def _optional_int_value(value: object) -> int | None:
    if value in (None, ""):
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _optional_positive_int(value: object) -> int | None:
    parsed = _optional_int_value(value)
    if parsed is None or parsed <= 0:
        return None
    return parsed


def _optional_nonnegative_int(value: object) -> int | None:
    parsed = _optional_int_value(value)
    if parsed is None or parsed < 0:
        return None
    return parsed


def _attach_local_llm_hybrid_fallback_candidate(
    candidate_data: dict,
    *,
    raw_score_version_id: str,
    rendered_score_version_id: str,
    canonical_score_version_id: str,
    llm_result,
    measure_reviews: list[dict],
    visual_diff: dict | None,
    job_id: str,
) -> dict:
    hybrid_candidate = build_hybrid_fallback_candidate(
        candidate_id=f"hybrid_fallback_{job_id[:8]}",
        raw_score_version_id=raw_score_version_id,
        rendered_score_version_id=rendered_score_version_id,
        canonical_score_version_id=canonical_score_version_id,
        notation_findings=list(llm_result.notation_findings or []),
        measure_reviews=measure_reviews,
        visual_diff=visual_diff,
        reason="No verified MusicXML correction was accepted by the quality loop.",
    )
    existing_candidates = [
        candidate
        for candidate in candidate_data.get("omr_candidates") or []
        if isinstance(candidate, dict)
        and candidate.get("candidate_id") != hybrid_candidate["candidate_id"]
    ]
    candidate_data["omr_candidates"] = [hybrid_candidate, *existing_candidates]
    candidate_data["hybrid_fallback_candidate_id"] = hybrid_candidate["candidate_id"]
    candidate_data["hybrid_fallback_available"] = True
    candidate_data["hybrid_fallback_reason"] = hybrid_candidate["hybrid_fallback_reason"]
    return candidate_data


def _record_local_llm_score_status(
    candidate_data: dict,
    *,
    job: BackgroundJob,
    llm_result,
    status: str,
    parent_notes: str | None,
    tool_results: list,
    visual_diff: dict | None = None,
    render_warnings: list[str] | None = None,
    selected_candidate_id: str | None = None,
    corrected_canonical_score_version_id: str | None = None,
    corrected_rendered_score_version_id: str | None = None,
    measure_reviews: list[dict] | None = None,
    quality_loop: dict | None = None,
    retry_attempted: bool = False,
) -> dict:
    warnings = list(llm_result.warnings or []) + list(render_warnings or [])
    tool_result_payload = _score_tool_results_payload(tool_results)
    measure_review_payload = list(measure_reviews or [])
    candidate_data["llm_review_status"] = status
    candidate_data["llm_notation_review_status"] = status
    candidate_data["llm_review_provider"] = llm_result.provider
    candidate_data["llm_review_job_id"] = job.id
    candidate_data["llm_review_summary"] = llm_result.summary
    candidate_data["llm_audit_summary"] = llm_result.audit_summary
    candidate_data["llm_notation_findings"] = list(llm_result.notation_findings or [])
    candidate_data["llm_tool_results"] = tool_result_payload
    candidate_data["llm_measure_reviews"] = measure_review_payload
    candidate_data["llm_model"] = llm_result.model
    candidate_data["llm_vision_model_hint"] = llm_result.vision_model_hint
    candidate_data["llm_model_auto_selected"] = llm_result.model_auto_selected
    candidate_data["llm_retry_attempted"] = retry_attempted
    if quality_loop is not None:
        candidate_data["score_quality_loop"] = quality_loop
    candidate_data["llm_correction_scope"] = (
        "notation"
        if status == "notation_corrected"
        else "metadata_or_layout"
        if status == "metadata_or_layout_only"
        else "finding_only"
        if status == "finding_only"
        else "audit_only"
    )
    if visual_diff is not None:
        candidate_data["llm_visual_diff"] = visual_diff
    if warnings:
        candidate_data["validation_warnings"] = sorted(
            set(list(candidate_data.get("validation_warnings") or []) + warnings)
        )

    history = list(candidate_data.get("reprocess_history") or [])
    history.append(
        {
            "reprocess_type": "score",
            "status": "succeeded",
            "outcome": status,
            "provider": llm_result.provider,
            "summary": llm_result.summary,
            "audit_summary": llm_result.audit_summary,
            "parent_notes": parent_notes,
            "notation_findings": list(llm_result.notation_findings or []),
            "tool_results": tool_result_payload,
            "measure_reviews": measure_review_payload,
            "score_quality_loop": quality_loop,
            "visual_diff": visual_diff,
            "model": llm_result.model,
            "vision_model_hint": llm_result.vision_model_hint,
            "model_auto_selected": llm_result.model_auto_selected,
            "retry_attempted": retry_attempted,
            "created_at": datetime.utcnow().isoformat(),
        }
    )
    candidate_data["reprocess_history"] = history

    result_data = {
        **(job.result_data or {}),
        "local_llm_available": True,
        "provider": llm_result.provider,
        "model": llm_result.model,
        "review_item_id": job.result_data.get("review_item_id") if job.result_data else None,
        "llm_notation_review_status": status,
        "summary": llm_result.summary,
        "audit_summary": llm_result.audit_summary,
        "notation_findings": list(llm_result.notation_findings or []),
        "tool_results": tool_result_payload,
        "measure_reviews": measure_review_payload,
        "score_quality_loop": quality_loop,
        "visual_diff": visual_diff,
        "vision_model_hint": llm_result.vision_model_hint,
        "model_auto_selected": llm_result.model_auto_selected,
        "retry_attempted": retry_attempted,
        "warnings": warnings,
    }
    if selected_candidate_id:
        result_data["selected_omr_candidate_id"] = selected_candidate_id
    if corrected_canonical_score_version_id:
        result_data["canonical_score_version_id"] = corrected_canonical_score_version_id
    if corrected_rendered_score_version_id:
        result_data["rendered_score_version_id"] = corrected_rendered_score_version_id
    job.result_data = result_data
    return candidate_data


def _score_tool_results_payload(tool_results: list) -> list[dict]:
    return [
        {
            "name": result.name,
            "status": result.status,
            "message": result.message,
            "affects_notation": bool(getattr(result, "affects_notation", False)),
            "structured_content": result.structured_content,
        }
        for result in tool_results
    ]


async def _run_gemini_score_reprocess(
    db: AsyncSession,
    *,
    item: ReviewItem,
    job: BackgroundJob,
    candidate_data: dict,
    parent_notes: str | None,
) -> dict:
    settings_payload = _processing_settings_store.load()
    if (settings_payload.get("cloud_provider") or "gemini") != "gemini":
        raise GeminiVisionReviewError("Gemini vision review requires cloud provider gemini.")
    if (settings_payload.get("cloud_auth_mode") or "oauth") != "oauth":
        raise GeminiVisionReviewError("Gemini vision review requires Google OAuth.")

    raw_version, rendered_version, canonical_version = await _score_versions_for_review(
        db,
        candidate_data,
        provider_label="Gemini review",
        error_factory=GeminiVisionReviewError,
    )
    raw_path = Path(raw_version.file_path)
    rendered_path = Path(rendered_version.file_path)
    canonical_path = Path(canonical_version.file_path)
    for label, path in (
        ("original PDF", raw_path),
        ("rendered candidate PDF", rendered_path),
        ("MusicXML candidate", canonical_path),
    ):
        if not path.exists():
            raise GeminiVisionReviewError(f"Gemini review cannot find the {label}: {path}")

    job.progress = 25.0
    job.updated_at = datetime.utcnow()
    await db.flush()

    gemini_result = _gemini_vision_adapter.review_score(
        raw_pdf_path=raw_path,
        rendered_pdf_path=rendered_path,
        canonical_musicxml_path=canonical_path,
        candidate_data=candidate_data,
        parent_notes=parent_notes,
    )
    if not gemini_result.tool_calls:
        raise GeminiVisionReviewError(
            "Gemini completed review but did not return any safe MusicXML edits."
        )

    job.progress = 55.0
    job.updated_at = datetime.utcnow()
    await db.flush()

    workspace = canonical_path.parent / "gemini-review" / job.id
    tool_controller = ScoreMcpToolController(
        source_musicxml_path=canonical_path,
        workspace_path=workspace,
    )
    tool_results = tool_controller.apply_tool_calls(gemini_result.tool_calls)
    if not any(result.name == "replace_musicxml_text" for result in tool_results):
        raise GeminiVisionReviewError("Gemini did not request a safe MusicXML replacement.")

    job.progress = 72.0
    job.updated_at = datetime.utcnow()
    await db.flush()

    corrected_canonical_path = tool_controller.working_musicxml_path
    _validate_musicxml(corrected_canonical_path)
    corrected_rendered_path = workspace / "candidate.pdf"
    render_result = MuseScoreRenderEngine().render(
        canonical_path=corrected_canonical_path,
        raw_pdf_path=raw_path,
        output_pdf_path=corrected_rendered_path,
        processing_settings=settings_payload,
    )
    if render_result.validation_status != "valid":
        raise ProcessingEngineError(
            render_result.validation_error or "Gemini MusicXML correction rendered an invalid PDF."
        )

    corrected_canonical_version = ScoreVersion(
        id=str(uuid.uuid4()),
        piece_id=item.piece_id,
        version_type=ScoreVersionType.reconstructed_candidate,
        file_path=str(corrected_canonical_path),
        is_default=False,
        created_at=datetime.utcnow(),
    )
    corrected_rendered_version = ScoreVersion(
        id=str(uuid.uuid4()),
        piece_id=item.piece_id,
        version_type=ScoreVersionType.reconstructed_candidate,
        file_path=str(corrected_rendered_path),
        is_default=False,
        created_at=datetime.utcnow(),
    )
    db.add(corrected_canonical_version)
    db.add(corrected_rendered_version)
    await db.flush()

    candidate_id = f"gemini_{job.id[:8]}"
    gemini_candidate = {
        "candidate_id": candidate_id,
        "label": "Gemini vision correction",
        "engine_name": "gemini",
        "engine_version": settings_payload.get("cloud_model") or "gemini-2.5-flash",
        "provenance": "gemini_vision_mcp",
        "confidence": gemini_result.confidence,
        "raw_score_version_id": raw_version.id,
        "canonical_score_version_id": corrected_canonical_version.id,
        "score_version_id": corrected_rendered_version.id,
        "renderer_name": render_result.renderer_name,
        "renderer_version": render_result.renderer_version,
        "renderer_provenance": render_result.provenance,
        "render_validation_status": render_result.validation_status,
        "render_validation_error": render_result.validation_error,
        "rendered_file_size_bytes": render_result.file_size_bytes,
        "rendered_page_count": render_result.page_count,
        "render_diagnostics": render_result.diagnostics,
        "warnings": gemini_result.warnings + render_result.warnings,
        "selected": True,
    }

    previous_candidates = [
        {**candidate, "selected": False}
        for candidate in candidate_data.get("omr_candidates") or []
        if isinstance(candidate, dict)
    ]
    candidate_data["omr_candidates"] = [gemini_candidate, *previous_candidates]
    for key, value in gemini_candidate.items():
        if key not in {"candidate_id", "label", "warnings", "selected"}:
            candidate_data[key] = value
    candidate_data["selected_omr_candidate_id"] = candidate_id
    candidate_data["selected_omr_candidate_label"] = gemini_candidate["label"]
    candidate_data["gemini_review_status"] = "completed"
    candidate_data["gemini_review_job_id"] = job.id
    candidate_data["gemini_review_summary"] = gemini_result.summary
    candidate_data["validation_warnings"] = sorted(
        set(
            list(candidate_data.get("validation_warnings") or [])
            + gemini_result.warnings
            + render_result.warnings
        )
    )
    history = list(candidate_data.get("reprocess_history") or [])
    history.append(
        {
            "reprocess_type": "score",
            "status": "succeeded",
            "provider": "gemini",
            "summary": gemini_result.summary,
            "parent_notes": parent_notes,
            "tool_results": [
                {
                    "name": result.name,
                    "status": result.status,
                    "message": result.message,
                    "structured_content": result.structured_content,
                }
                for result in tool_results
            ],
            "created_at": datetime.utcnow().isoformat(),
        }
    )
    candidate_data["reprocess_history"] = history
    job.result_data = {
        **(job.result_data or {}),
        "gemini_available": True,
        "provider": "gemini",
        "model": settings_payload.get("cloud_model") or "gemini-2.5-flash",
        "review_item_id": item.id,
        "selected_omr_candidate_id": candidate_id,
        "canonical_score_version_id": corrected_canonical_version.id,
        "rendered_score_version_id": corrected_rendered_version.id,
        "summary": gemini_result.summary,
        "warnings": gemini_result.warnings + render_result.warnings,
    }
    return candidate_data


async def _score_versions_for_review(
    db: AsyncSession,
    candidate_data: dict,
    *,
    provider_label: str,
    error_factory: type[Exception],
) -> tuple[ScoreVersion, ScoreVersion, ScoreVersion]:
    raw_id = candidate_data.get("raw_score_version_id")
    rendered_id = candidate_data.get("score_version_id")
    canonical_id = candidate_data.get("canonical_score_version_id")
    required_ids = (raw_id, rendered_id, canonical_id)
    if not all(isinstance(value, str) and value.strip() for value in required_ids):
        raise error_factory(
            f"{provider_label} requires original score, rendered PDF, "
            "and MusicXML candidate artifacts."
        )
    raw_version = await db.get(ScoreVersion, raw_id)
    rendered_version = await db.get(ScoreVersion, rendered_id)
    canonical_version = await db.get(ScoreVersion, canonical_id)
    if not raw_version or not rendered_version or not canonical_version:
        raise error_factory(f"{provider_label} could not load all required score artifacts.")
    return raw_version, rendered_version, canonical_version


def _apply_review_correction(
    candidate_data: dict,
    correction: dict | None,
    *,
    fallback_metadata: dict | None = None,
) -> dict:
    fallback_metadata = {
        key: value
        for key, value in dict(fallback_metadata or {}).items()
        if value not in (None, "", [])
    }
    if not correction:
        existing = candidate_data.get("catalog_metadata")
        if isinstance(existing, dict) and existing:
            candidate_data["catalog_metadata"] = existing
        elif fallback_metadata:
            candidate_data["catalog_metadata"] = fallback_metadata
        else:
            candidate_data["catalog_metadata"] = _first_catalog_suggestion_fields(candidate_data)
        return candidate_data
    catalog_metadata = dict(candidate_data.get("catalog_metadata") or fallback_metadata)
    catalog_metadata.update(
        {
            key: value
            for key, value in correction.items()
            if key
            in {
                "title",
                "composer",
                "primary_instrument",
                "book_or_collection",
                "key_signature",
                "tempo",
                "aliases",
                "arranger",
                "editor",
                "opus",
                "catalog_number",
                "publisher",
                "source_page_start",
                "source_page_end",
                "source_file_name",
                "notes",
            }
            and value not in (None, "", [])
        }
    )
    candidate_data["catalog_metadata"] = catalog_metadata
    return candidate_data


def _authoritative_catalog_metadata(piece: Piece, candidate_data: dict) -> dict:
    """Return parent/book-approved metadata that should outrank OCR suggestions."""

    current = _piece_state_service.metadata_for_piece(piece)
    metadata = dict(current.get("catalog_metadata") or {})
    for key, value in {
        "title": piece.title,
        "composer": piece.composer,
        "primary_instrument": current.get("primary_instrument"),
        "book_or_collection": current.get("book_or_collection"),
        "key_signature": piece.key_signature,
        "tempo": piece.tempo,
        "source_page_start": current.get("source_page_start")
        or candidate_data.get("source_page_start"),
        "source_page_end": current.get("source_page_end") or candidate_data.get("source_page_end"),
    }.items():
        if value not in (None, "", []):
            metadata[key] = value
    return {key: value for key, value in metadata.items() if value not in (None, "", [])}


def _apply_catalog_metadata_to_piece(piece: Piece, candidate_data: dict) -> None:
    catalog_metadata = candidate_data.get("catalog_metadata") or {}
    if not isinstance(catalog_metadata, dict):
        return
    if isinstance(catalog_metadata.get("title"), str):
        piece.title = catalog_metadata["title"]
    if isinstance(catalog_metadata.get("composer"), str):
        piece.composer = catalog_metadata["composer"]
    if isinstance(catalog_metadata.get("key_signature"), str):
        piece.key_signature = catalog_metadata["key_signature"]
    if isinstance(catalog_metadata.get("tempo"), str):
        piece.tempo = catalog_metadata["tempo"]

    current = _piece_state_service.metadata_for_piece(piece)
    _piece_state_service.upsert_metadata(
        piece.id,
        title=piece.title,
        composer=piece.composer,
        primary_instrument=catalog_metadata.get("primary_instrument")
        or current["primary_instrument"],
        book_or_collection=catalog_metadata.get("book_or_collection")
        or current["book_or_collection"],
        visible_to_profile_ids=current["visible_to_profile_ids"],
        processed_metadata=current["processed_metadata"],
        piece_kind=current["piece_kind"],
        source_book_id=current["source_book_id"],
        source_page_start=current["source_page_start"],
        source_page_end=current["source_page_end"],
        catalog_metadata=catalog_metadata,
        catalog_suggestions=current["catalog_suggestions"],
        validation_warnings=current["validation_warnings"],
        split_confidence=current["split_confidence"],
        notes=catalog_metadata.get("notes") or current["notes"],
    )


def _with_omr_candidate_urls(
    request: Request,
    piece_id: str,
    candidate_data: dict,
) -> dict:
    candidates = candidate_data.get("omr_candidates")
    if not isinstance(candidates, list):
        return candidate_data

    enriched_candidates = []
    for candidate in candidates:
        if not isinstance(candidate, dict):
            continue
        enriched = dict(candidate)
        raw_id = enriched.get("raw_score_version_id") or candidate_data.get("raw_score_version_id")
        rendered_id = enriched.get("score_version_id")
        canonical_id = enriched.get("canonical_score_version_id")
        if raw_id:
            enriched.setdefault("raw_file_url", _file_url(request, piece_id, raw_id))
        if rendered_id and _candidate_render_is_valid(enriched):
            enriched.setdefault(
                "rendered_file_url",
                _file_url(request, piece_id, rendered_id),
            )
        if canonical_id:
            enriched.setdefault(
                "canonical_file_url",
                _file_url(request, piece_id, canonical_id),
            )
        enriched_candidates.append(enriched)
    candidate_data["omr_candidates"] = enriched_candidates
    return candidate_data


def _select_omr_candidate(
    candidate_data: dict,
    *,
    selected_candidate_id: str | None,
) -> dict:
    candidates = [
        dict(candidate)
        for candidate in candidate_data.get("omr_candidates") or []
        if isinstance(candidate, dict)
    ]
    if not candidates:
        return candidate_data

    selected_id = selected_candidate_id or candidate_data.get("selected_omr_candidate_id") or ""
    selected_id = str(selected_id).strip() or str(candidates[0].get("candidate_id") or "")
    selected_candidate = next(
        (
            candidate
            for candidate in candidates
            if str(candidate.get("candidate_id") or "") == selected_id
        ),
        None,
    )
    if selected_candidate is None:
        raise HTTPException(status_code=400, detail="Selected OMR candidate was not found.")

    selected_id = str(selected_candidate.get("candidate_id") or selected_id)
    for key in (
        "engine_name",
        "engine_version",
        "provenance",
        "confidence",
        "processed_metadata",
        "renderer_name",
        "renderer_version",
        "renderer_provenance",
        "render_validation_status",
        "render_validation_error",
        "rendered_file_size_bytes",
        "rendered_page_count",
        "render_diagnostics",
        "raw_score_version_id",
        "score_version_id",
        "canonical_score_version_id",
    ):
        if key in selected_candidate:
            candidate_data[key] = selected_candidate[key]
    candidate_data["selected_omr_candidate_id"] = selected_id
    candidate_data["selected_omr_candidate_label"] = selected_candidate.get("label")
    if selected_candidate.get("warnings"):
        candidate_data["warnings"] = sorted(
            set(
                list(candidate_data.get("warnings") or [])
                + list(selected_candidate.get("warnings") or [])
            )
        )
    candidate_data["omr_candidates"] = [
        {**candidate, "selected": str(candidate.get("candidate_id") or "") == selected_id}
        for candidate in candidates
    ]
    return candidate_data


def _candidate_score_version_ids(candidate_data: dict) -> set[str]:
    score_version_ids = {
        value
        for value in (
            candidate_data.get("score_version_id"),
            candidate_data.get("canonical_score_version_id"),
        )
        if isinstance(value, str) and value.strip()
    }
    for candidate in candidate_data.get("omr_candidates") or []:
        if not isinstance(candidate, dict):
            continue
        for key in ("score_version_id", "canonical_score_version_id"):
            value = candidate.get(key)
            if isinstance(value, str) and value.strip():
                score_version_ids.add(value.strip())
    return score_version_ids


async def _refresh_candidate_output_for_metadata(
    db: AsyncSession,
    *,
    piece: Piece,
    candidate_data: dict,
) -> dict:
    canonical_score_id = candidate_data.get("canonical_score_version_id")
    rendered_score_id = candidate_data.get("score_version_id")
    raw_score_id = candidate_data.get("raw_score_version_id")
    if not canonical_score_id or not rendered_score_id or not raw_score_id:
        return candidate_data

    canonical_version = await db.get(ScoreVersion, canonical_score_id)
    rendered_version = await db.get(ScoreVersion, rendered_score_id)
    raw_version = await db.get(ScoreVersion, raw_score_id)
    if not canonical_version or not rendered_version or not raw_version:
        return candidate_data

    canonical_path = Path(canonical_version.file_path)
    raw_path = Path(raw_version.file_path)
    rendered_path = Path(rendered_version.file_path)
    if not canonical_path.exists() or not raw_path.exists():
        return candidate_data

    catalog_metadata = candidate_data.get("catalog_metadata") or {}
    if not isinstance(catalog_metadata, dict):
        catalog_metadata = {}
    state = _piece_state_service.metadata_for_piece(piece)
    title = str(catalog_metadata.get("title") or piece.title)
    composer = catalog_metadata.get("composer") or piece.composer
    primary_instrument = catalog_metadata.get("primary_instrument") or state["primary_instrument"]
    contained_piece_titles = (
        candidate_data.get("contained_piece_titles")
        or catalog_metadata.get("contained_piece_titles")
        or [title]
    )
    multi_piece_page = bool(
        candidate_data.get("multi_piece_page") or catalog_metadata.get("multi_piece_page")
    )

    normalized_path = _normalize_musicxml_metadata(
        canonical_path,
        output_path=canonical_path,
        title=title,
        composer=composer,
        primary_instrument=primary_instrument,
        contained_piece_titles=contained_piece_titles,
        multi_piece_page=multi_piece_page,
    )
    musicxml_metadata = _validate_musicxml(normalized_path)
    render_result = MuseScoreRenderEngine().render(
        canonical_path=normalized_path,
        raw_pdf_path=raw_path,
        output_pdf_path=rendered_path,
        processing_settings=_processing_settings_store.load(),
    )

    processed_metadata = dict(candidate_data.get("processed_metadata") or {})
    processed_metadata.update(
        {key: value for key, value in musicxml_metadata.items() if value not in (None, "", [])}
    )
    if primary_instrument:
        processed_metadata["primary_instrument"] = primary_instrument
    candidate_data["processed_metadata"] = processed_metadata
    candidate_data["renderer_name"] = render_result.renderer_name
    candidate_data["renderer_version"] = render_result.renderer_version
    candidate_data["renderer_provenance"] = render_result.provenance
    candidate_data["render_validation_status"] = render_result.validation_status
    candidate_data["render_validation_error"] = render_result.validation_error
    candidate_data["rendered_file_size_bytes"] = render_result.file_size_bytes
    candidate_data["rendered_page_count"] = render_result.page_count
    candidate_data["render_diagnostics"] = render_result.diagnostics
    candidate_data["metadata_rerendered_at"] = datetime.utcnow().isoformat()
    if render_result.warnings:
        candidate_data["warnings"] = sorted(
            set(list(candidate_data.get("warnings") or []) + render_result.warnings)
        )
    return candidate_data


def _candidate_render_is_valid(candidate_data: dict) -> bool:
    status = candidate_data.get("render_validation_status")
    if status in (None, "", "valid"):
        return True
    return False


def _candidate_render_validation_error(candidate_data: dict) -> str | None:
    error = candidate_data.get("render_validation_error")
    if isinstance(error, str) and error.strip():
        return error.strip()
    return None


def _first_catalog_suggestion_fields(candidate_data: dict) -> dict:
    suggestions = candidate_data.get("catalog_suggestions") or []
    if not isinstance(suggestions, list):
        return {}
    for suggestion in suggestions:
        if not isinstance(suggestion, dict):
            continue
        fields = suggestion.get("fields")
        if isinstance(fields, dict):
            return fields
    return {}


def _append_reprocess_warning(
    candidate_data: dict,
    *,
    reprocess_type: str,
    warning: str,
    parent_notes: str | None,
) -> dict:
    warnings = list(candidate_data.get("validation_warnings") or [])
    warnings.append(warning)
    history = list(candidate_data.get("reprocess_history") or [])
    history.append(
        {
            "reprocess_type": reprocess_type,
            "status": "failed",
            "warning": warning,
            "parent_notes": parent_notes,
            "created_at": datetime.utcnow().isoformat(),
        }
    )
    candidate_data["validation_warnings"] = warnings
    candidate_data["reprocess_history"] = history
    return candidate_data


def _trigger_media_search_async(piece: Piece) -> None:
    """Fire-and-forget YouTube reference search after piece approval."""
    import asyncio  # noqa: PLC0414

    async def _do_search() -> None:
        from server.database import async_session as _async_session  # noqa: PLC0414
        from server.services.youtube_search import (  # noqa: PLC0414
            search_reference_media,
        )

        try:
            async with _async_session() as db:
                await search_reference_media(piece, db)
        except Exception:
            pass  # Background task failures are non-critical

    asyncio.create_task(_do_search())
