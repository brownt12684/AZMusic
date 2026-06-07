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

router = APIRouter()
_piece_state_service = PieceStateService()
_processing_settings_store = ProcessingSettingsStore()
_BULK_APPROVAL_STAGES = {"split_review_needed", "candidate_review_needed"}


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
            detail="processing_stage must be split_review_needed or candidate_review_needed.",
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
        if candidate_data.get("processing_stage") == "split_review_needed":
            item.status = "approved"
            candidate_data = _apply_review_correction(candidate_data, correction)
            item.candidate_data = candidate_data
            piece = await db.get(Piece, item.piece_id)
            if piece:
                _apply_catalog_metadata_to_piece(piece, candidate_data)
                piece.status = PieceStatus.processing
                piece.updated_at = datetime.utcnow()
            db.add(
                BackgroundJob(
                    id=str(uuid.uuid4()),
                    piece_id=item.piece_id,
                    job_type="score_processing",
                    status=JobStatus.queued,
                    progress=0.0,
                    result_data={
                        "source_review_item_id": item.id,
                        "raw_score_version_id": raw_score_id,
                        "processing_stage": "queued_after_split_review",
                        "source_book_id": candidate_data.get("source_book_id"),
                        "source_page_start": candidate_data.get("source_page_start"),
                        "source_page_end": candidate_data.get("source_page_end"),
                        "primary_instrument": (
                            (candidate_data.get("catalog_metadata") or {}).get("primary_instrument")
                            if isinstance(candidate_data.get("catalog_metadata"), dict)
                            else None
                        ),
                        "contained_piece_titles": candidate_data.get("contained_piece_titles"),
                        "multi_piece_page": candidate_data.get("multi_piece_page"),
                    },
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow(),
                )
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
        elif item.item_type == ReviewItemType.score_candidate and raw_score_id:
            result = await db.execute(select(ScoreVersion).where(ScoreVersion.id == raw_score_id))
            raw_version = result.scalar_one_or_none()
            if raw_version:
                raw_version.is_default = True
                raw_version.version_type = ScoreVersionType.approved

        if canonical_score_id:
            result = await db.execute(
                select(ScoreVersion).where(ScoreVersion.id == canonical_score_id)
            )
            canonical_version = result.scalar_one_or_none()
            if canonical_version:
                canonical_version.version_type = ScoreVersionType.approved

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
    else:
        raise HTTPException(status_code=400, detail="Unsupported review action.")


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
        message = (
            "AI score review is coming soon. It will compare the original PDF, "
            "metadata, and MuseScore candidate, apply corrections, rerender, "
            "and return the candidate for parent review."
        )
        job.status = JobStatus.failed
        job.progress = 100.0
        job.error_message = message
        job.result_data = {
            **(job.result_data or {}),
            "coming_soon": True,
            "warnings": [message],
        }
        job.updated_at = datetime.utcnow()
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

    provider = LocalLlmProvider(_processing_settings_store.load())
    try:
        llm_result = provider.reprocess_review_item(
            reprocess_type=body.reprocess_type.value,
            candidate_data=candidate_data,
            parent_notes=body.parent_notes,
        )
    except LocalLlmUnavailableError as exc:
        job.status = JobStatus.failed
        job.progress = 100.0
        job.error_message = str(exc)
        job.result_data = {
            **(job.result_data or {}),
            "local_llm_available": False,
            "warnings": [str(exc)],
        }
        job.updated_at = datetime.utcnow()
        _processing_settings_store.record_last_llm_error(str(exc))
        candidate_data = _append_reprocess_warning(
            candidate_data,
            reprocess_type=body.reprocess_type.value,
            warning=str(exc),
            parent_notes=body.parent_notes,
        )
        item.candidate_data = candidate_data
    else:
        job.status = JobStatus.succeeded
        job.progress = 100.0
        job.result_data = {
            **(job.result_data or {}),
            "local_llm_available": True,
            "provider": llm_result.provider,
            "model": llm_result.model,
            "suggestions": llm_result.suggestions,
            "warnings": llm_result.warnings,
        }
        job.updated_at = datetime.utcnow()
        _processing_settings_store.record_last_llm_error(None)
        candidate_data = _append_catalog_suggestions(
            candidate_data,
            suggestions=llm_result.suggestions,
            warnings=llm_result.warnings,
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
            candidate_data["catalog_metadata"] = _first_catalog_suggestion_fields(
                candidate_data
            )
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
        raw_id = enriched.get("raw_score_version_id") or candidate_data.get(
            "raw_score_version_id"
        )
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

    selected_id = (selected_candidate_id or candidate_data.get("selected_omr_candidate_id") or "")
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


def _append_catalog_suggestions(
    candidate_data: dict,
    *,
    suggestions: list[dict],
    warnings: list[str],
) -> dict:
    candidate_data["catalog_suggestions"] = (
        list(candidate_data.get("catalog_suggestions") or []) + suggestions
    )
    if warnings:
        candidate_data["validation_warnings"] = (
            list(candidate_data.get("validation_warnings") or []) + warnings
        )
    return candidate_data
