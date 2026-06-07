"""Score import orchestration and review-candidate generation."""

from __future__ import annotations

import asyncio
import subprocess
import uuid
from dataclasses import dataclass, field
from datetime import datetime
from functools import partial
from io import BytesIO
from pathlib import Path

from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.config import settings
from server.models.orm import (
    BackgroundJob,
    JobStatus,
    Piece,
    PieceStatus,
    ReviewItem,
    ReviewItemType,
    ScoreVersion,
    ScoreVersionType,
)
from server.services.book_preprocessing import (
    BookPageFact,
    BookPreprocessingResult,
    BookPreprocessor,
    BookSplitProposal,
    _analyze_page_image,
)
from server.services.ocr_metadata import OcrMetadataExtractor
from server.services.piece_state import PieceStateService
from server.services.processing_engines import (
    MuseScoreRenderEngine,
    MusicXmlEngine,
    ProcessingEngineError,
    RenderResult,
    _normalize_musicxml_metadata_with_spacing,
    _validate_musicxml,
    validate_rendered_pdf,
)
from server.services.processing_settings import ProcessingSettingsStore, executable_status

__all__ = [
    "BookPageFact",
    "BookPreprocessingResult",
    "BookPreprocessor",
    "BookSplitProposal",
    "JobCanceledError",
    "ScoreProcessingService",
]


class JobCanceledError(RuntimeError):
    """Raised when a background job was canceled by parent debug tools."""


@dataclass(slots=True)
class ImportedPieceArtifacts:
    piece: Piece
    raw_score_version: ScoreVersion
    canonical_score_version: ScoreVersion | None
    rendered_score_version: ScoreVersion | None
    review_item: ReviewItem | None
    job: BackgroundJob
    ocr_metadata: dict[str, object] = field(default_factory=dict)
    ocr_catalog_suggestions: list[dict[str, object]] = field(default_factory=list)
    musicxml_metadata: dict[str, object] = field(default_factory=dict)


class BookSplitHint(BaseModel):
    """Conservative child-piece boundary supplied by detection or review tooling."""

    title: str = Field(..., min_length=1, max_length=500)
    page_start: int = Field(..., ge=1)
    page_end: int = Field(..., ge=1)
    composer: str | None = Field(default=None, max_length=300)
    primary_instrument: str | None = Field(default=None, max_length=200)
    key_signature: str | None = Field(default=None, max_length=50)
    tempo: str | None = Field(default=None, max_length=50)
    aliases: list[str] = Field(default_factory=list)
    contained_piece_titles: list[str] = Field(default_factory=list)
    multi_piece_page: bool = False
    confidence: float = Field(default=0.75, ge=0.0, le=1.0)
    validation_warnings: list[str] = Field(default_factory=list)


@dataclass(slots=True)
class ImportedBookArtifacts:
    book_piece: Piece
    raw_score_version: ScoreVersion
    child_artifacts: list[ImportedPieceArtifacts]
    child_split_hints: list[BookSplitHint]
    job: BackgroundJob
    validation_warnings: list[str]
    ocr_metadata: dict[str, object] = field(default_factory=dict)
    ocr_catalog_suggestions: list[dict[str, object]] = field(default_factory=list)
    preprocessing_result: BookPreprocessingResult | None = None


@dataclass(slots=True)
class OmrCandidateArtifact:
    candidate_id: str
    label: str
    canonical_path: Path
    rendered_path: Path
    engine_name: str
    engine_version: str | None
    provenance: str
    confidence: float
    quality_score: float | None
    musicxml_metadata: dict[str, object]
    processed_metadata: dict[str, object]
    render_result: RenderResult
    warnings: list[str]
    profile: str | None = None


class ScoreProcessingService:
    """Preserve raw imports and orchestrate configured processing engines."""

    async def import_pdf(
        self,
        db: AsyncSession,
        *,
        title: str,
        composer: str | None,
        file_name: str,
        file_bytes: bytes,
        primary_instrument: str | None = None,
        allow_title_override: bool = False,
        allow_composer_override: bool = False,
    ) -> ImportedPieceArtifacts:
        processing_settings_store = ProcessingSettingsStore()
        processing_settings = processing_settings_store.load()
        _ensure_production_processing_ready(processing_settings)
        ocr_result = OcrMetadataExtractor(processing_settings).extract(
            file_name=file_name,
            file_bytes=file_bytes,
        )
        ocr_metadata = dict(ocr_result.metadata)
        ocr_title = _metadata_string(ocr_metadata, "title")
        ocr_composer = _metadata_string(ocr_metadata, "composer")
        primary_instrument = primary_instrument or _metadata_string(
            ocr_metadata, "primary_instrument"
        )
        if allow_title_override and ocr_title:
            title = ocr_title
        if allow_composer_override and ocr_composer:
            composer = ocr_composer

        now = datetime.utcnow()
        piece_id = str(uuid.uuid4())
        piece_dir = settings.storage_path / "pieces" / piece_id
        piece_dir.mkdir(parents=True, exist_ok=True)

        raw_ext = Path(file_name).suffix or ".pdf"
        raw_path = piece_dir / f"raw_source{raw_ext.lower()}"
        raw_path.write_bytes(file_bytes)

        piece = Piece(
            id=piece_id,
            title=title,
            composer=composer,
            file_name=file_name,
            status=PieceStatus.processing,
            created_at=now,
            updated_at=now,
        )
        raw_score_version = ScoreVersion(
            id=str(uuid.uuid4()),
            piece_id=piece_id,
            version_type=ScoreVersionType.raw,
            file_path=str(raw_path),
            is_default=True,
            created_at=now,
        )
        job = BackgroundJob(
            id=str(uuid.uuid4()),
            piece_id=piece_id,
            job_type="score_processing",
            status=JobStatus.running,
            progress=10.0,
            created_at=now,
            updated_at=now,
        )

        db.add(piece)
        db.add(raw_score_version)
        db.add(job)
        await db.flush()

        warnings: list[str] = list(ocr_result.warnings)
        processed_metadata: dict[str, object] = {}
        musicxml_metadata: dict[str, object] = {}

        try:
            job.progress = 20.0
            job.updated_at = datetime.utcnow()
            await db.flush()

            canonical_path = piece_dir / "candidate.musicxml"
            musicxml_result = MusicXmlEngine().generate(
                raw_pdf_path=raw_path,
                output_path=canonical_path,
                title=title,
                composer=composer,
                primary_instrument=primary_instrument,
                contained_piece_titles=None,
                multi_piece_page=False,
                processing_settings=processing_settings,
            )
            warnings.extend(musicxml_result.warnings)
            musicxml_metadata = dict(musicxml_result.metadata)
            processed_metadata = _merge_metadata(ocr_metadata, musicxml_metadata)
            if not piece.composer and isinstance(processed_metadata.get("composer"), str):
                piece.composer = processed_metadata["composer"]
            if not piece.key_signature and isinstance(processed_metadata.get("key_signature"), str):
                piece.key_signature = processed_metadata["key_signature"]
            if not piece.tempo and isinstance(processed_metadata.get("tempo"), str):
                piece.tempo = processed_metadata["tempo"]
            job.progress = 60.0
            job.updated_at = datetime.utcnow()

            canonical_score_version = ScoreVersion(
                id=str(uuid.uuid4()),
                piece_id=piece_id,
                version_type=ScoreVersionType.reconstructed_candidate,
                file_path=str(musicxml_result.file_path),
                is_default=False,
                created_at=now,
            )
            db.add(canonical_score_version)
            await db.flush()

            rendered_path = piece_dir / "candidate_review.pdf"
            render_error: Exception | None = None
            try:
                render_result = MuseScoreRenderEngine().render(
                    canonical_path=musicxml_result.file_path,
                    raw_pdf_path=raw_path,
                    output_pdf_path=rendered_path,
                    processing_settings=processing_settings,
                )
            except (OSError, ProcessingEngineError, subprocess.TimeoutExpired) as exc:
                render_error = exc
                render_result = _blocked_render_result(rendered_path, exc)
            _repair_multi_piece_review_pdf_titles(
                render_result,
                contained_piece_titles=None,
                multi_piece_page=False,
            )
            _attach_spacing_normalization_diagnostics(render_result, musicxml_metadata)
            warnings.extend(render_result.warnings)
            raw_page_count = _pdf_page_count(raw_path)
            warnings.extend(
                _score_candidate_review_warnings(
                    raw_pdf_path=raw_path,
                    raw_page_count=raw_page_count,
                    render_result=render_result,
                    musicxml_provenance=musicxml_result.provenance,
                    contained_piece_titles=None,
                    multi_piece_page=False,
                )
            )
            try:
                alternative_candidate_artifacts = _render_alternative_omr_candidate_artifacts(
                    piece_dir=piece_dir,
                    raw_path=raw_path,
                    selected_canonical_path=musicxml_result.file_path,
                    selected_engine_name=musicxml_result.engine_name,
                    title=title,
                    composer=composer,
                    primary_instrument=primary_instrument,
                    contained_piece_titles=None,
                    multi_piece_page=False,
                    ocr_metadata=ocr_metadata,
                    processing_settings=processing_settings,
                    raw_page_count=raw_page_count,
                    attempts=musicxml_metadata.get("omr_attempts"),
                )
            except (OSError, ProcessingEngineError, subprocess.TimeoutExpired) as exc:
                alternative_candidate_artifacts = []
                warnings.append(f"Alternative OMR candidate preparation failed: {exc}")
            job.progress = 82.0
            job.updated_at = datetime.utcnow()

            rendered_score_version = ScoreVersion(
                id=str(uuid.uuid4()),
                piece_id=piece_id,
                version_type=ScoreVersionType.reconstructed_candidate,
                file_path=str(render_result.file_path),
                is_default=False,
                created_at=now,
            )
            db.add(rendered_score_version)
            omr_candidates = [
                _selected_omr_candidate_payload(
                    candidate_id="selected_best",
                    label=f"Best: {_omr_candidate_label(musicxml_result.engine_name, None)}",
                    raw_score_version_id=raw_score_version.id,
                    canonical_score_version_id=canonical_score_version.id,
                    rendered_score_version_id=rendered_score_version.id,
                    musicxml_result=musicxml_result,
                    musicxml_metadata=musicxml_metadata,
                    processed_metadata=processed_metadata,
                    render_result=render_result,
                    warnings=warnings,
                    selected=True,
                )
            ]
            for alternative_artifact in alternative_candidate_artifacts:
                alternative_canonical_score_version = ScoreVersion(
                    id=str(uuid.uuid4()),
                    piece_id=piece_id,
                    version_type=ScoreVersionType.reconstructed_candidate,
                    file_path=str(alternative_artifact.canonical_path),
                    is_default=False,
                    created_at=now,
                )
                alternative_rendered_score_version = ScoreVersion(
                    id=str(uuid.uuid4()),
                    piece_id=piece_id,
                    version_type=ScoreVersionType.reconstructed_candidate,
                    file_path=str(alternative_artifact.rendered_path),
                    is_default=False,
                    created_at=now,
                )
                db.add(alternative_canonical_score_version)
                db.add(alternative_rendered_score_version)
                omr_candidates.append(
                    _omr_candidate_payload_from_artifact(
                        artifact=alternative_artifact,
                        raw_score_version_id=raw_score_version.id,
                        canonical_score_version_id=alternative_canonical_score_version.id,
                        rendered_score_version_id=alternative_rendered_score_version.id,
                        selected=False,
                    )
                )
            await db.flush()

            review_item = ReviewItem(
                id=str(uuid.uuid4()),
                piece_id=piece_id,
                item_type=ReviewItemType.score_candidate,
                title=f"Review reconstructed score for {title}",
                description=(
                    "Compare the rendered reconstruction against the original PDF "
                    "and approve it only if the default score is ready for students."
                ),
                status="pending",
                candidate_data={
                    "piece_title": title,
                    "summary": ("Server processing candidate prepared for parent review."),
                    "confidence": musicxml_result.confidence,
                    "provenance": musicxml_result.provenance,
                    "engine_name": musicxml_result.engine_name,
                    "engine_version": musicxml_result.engine_version,
                    "processed_metadata": processed_metadata,
                    "ocr_metadata": ocr_metadata,
                    "ocr_engine": ocr_result.engine_name,
                    "ocr_confidence": ocr_result.confidence,
                    "catalog_suggestions": ocr_result.catalog_suggestions,
                    "renderer_name": render_result.renderer_name,
                    "renderer_version": render_result.renderer_version,
                    "renderer_provenance": render_result.provenance,
                    "render_validation_status": render_result.validation_status,
                    "render_validation_error": render_result.validation_error,
                    "rendered_file_size_bytes": render_result.file_size_bytes,
                    "rendered_page_count": render_result.page_count,
                    "render_diagnostics": render_result.diagnostics,
                    "raw_page_count": raw_page_count,
                    "conversion_review_required": True,
                    "warnings": warnings,
                    "raw_score_version_id": raw_score_version.id,
                    "score_version_id": rendered_score_version.id,
                    "canonical_score_version_id": canonical_score_version.id,
                    "selected_omr_candidate_id": "selected_best",
                    "omr_candidates": omr_candidates,
                },
                created_at=now,
            )
            db.add(review_item)

            piece.status = PieceStatus.review_pending
            piece.updated_at = datetime.utcnow()
            job.status = (
                JobStatus.succeeded
                if render_result.validation_status == "valid"
                else JobStatus.failed
            )
            job.progress = 100.0
            job.error_message = str(render_error) if render_error else None
            job.result_data = {
                "review_item_id": review_item.id,
                "raw_score_version_id": raw_score_version.id,
                "rendered_score_version_id": rendered_score_version.id,
                "canonical_score_version_id": canonical_score_version.id,
                "selected_omr_candidate_id": "selected_best",
                "omr_candidate_count": len(omr_candidates),
                "engine_name": musicxml_result.engine_name,
                "engine_version": musicxml_result.engine_version,
                "processed_metadata": processed_metadata,
                "ocr_metadata": ocr_metadata,
                "ocr_engine": ocr_result.engine_name,
                "ocr_confidence": ocr_result.confidence,
                "catalog_suggestions": ocr_result.catalog_suggestions,
                "renderer_name": render_result.renderer_name,
                "renderer_version": render_result.renderer_version,
                "render_validation_status": render_result.validation_status,
                "render_validation_error": render_result.validation_error,
                "rendered_file_size_bytes": render_result.file_size_bytes,
                "rendered_page_count": render_result.page_count,
                "render_diagnostics": render_result.diagnostics,
                "raw_page_count": raw_page_count,
                "conversion_review_required": True,
                "warnings": warnings,
            }
            job.updated_at = datetime.utcnow()
            processing_settings_store.record_last_error(str(render_error) if render_error else None)

            await db.commit()
            await db.refresh(piece)
            await db.refresh(raw_score_version)
            await db.refresh(canonical_score_version)
            await db.refresh(rendered_score_version)
            await db.refresh(review_item)
            await db.refresh(job)
        except (OSError, ProcessingEngineError, subprocess.TimeoutExpired) as exc:
            job.status = JobStatus.failed
            job.progress = 100.0
            job.error_message = str(exc)
            job.result_data = {
                "raw_score_version_id": raw_score_version.id,
                "processed_metadata": processed_metadata,
                "warnings": warnings,
            }
            job.updated_at = datetime.utcnow()
            piece.status = PieceStatus.imported
            piece.updated_at = datetime.utcnow()
            processing_settings_store.record_last_error(str(exc))
            await db.commit()
            await db.refresh(piece)
            await db.refresh(raw_score_version)
            await db.refresh(job)
            return ImportedPieceArtifacts(
                piece=piece,
                raw_score_version=raw_score_version,
                canonical_score_version=None,
                rendered_score_version=None,
                review_item=None,
                job=job,
                ocr_metadata=ocr_metadata,
                ocr_catalog_suggestions=ocr_result.catalog_suggestions,
                musicxml_metadata=musicxml_metadata,
            )

        return ImportedPieceArtifacts(
            piece=piece,
            raw_score_version=raw_score_version,
            canonical_score_version=canonical_score_version,
            rendered_score_version=rendered_score_version,
            review_item=review_item,
            job=job,
            ocr_metadata=ocr_metadata,
            ocr_catalog_suggestions=ocr_result.catalog_suggestions,
            musicxml_metadata=musicxml_metadata,
        )

    async def import_image_scan(
        self,
        db: AsyncSession,
        *,
        title: str,
        composer: str | None,
        file_name: str,
        file_bytes: bytes,
        allow_title_override: bool = False,
        allow_composer_override: bool = False,
    ) -> ImportedPieceArtifacts:
        processing_settings = ProcessingSettingsStore().load()
        _ensure_production_processing_ready(processing_settings)
        ocr_result = OcrMetadataExtractor(processing_settings).extract(
            file_name=file_name,
            file_bytes=file_bytes,
        )
        ocr_metadata = dict(ocr_result.metadata)
        ocr_title = _metadata_string(ocr_metadata, "title")
        ocr_composer = _metadata_string(ocr_metadata, "composer")
        if allow_title_override and ocr_title:
            title = ocr_title
        if allow_composer_override and ocr_composer:
            composer = ocr_composer

        now = datetime.utcnow()
        piece_id = str(uuid.uuid4())
        piece_dir = settings.storage_path / "pieces" / piece_id
        piece_dir.mkdir(parents=True, exist_ok=True)

        raw_ext = Path(file_name).suffix.lower() or ".jpg"
        raw_path = piece_dir / f"raw_source{raw_ext}"
        raw_path.write_bytes(file_bytes)

        piece = Piece(
            id=piece_id,
            title=title,
            composer=composer,
            file_name=file_name,
            status=PieceStatus.review_pending,
            created_at=now,
            updated_at=now,
        )
        if isinstance(ocr_metadata.get("key_signature"), str):
            piece.key_signature = ocr_metadata["key_signature"]
        if isinstance(ocr_metadata.get("tempo"), str):
            piece.tempo = ocr_metadata["tempo"]

        raw_score_version = ScoreVersion(
            id=str(uuid.uuid4()),
            piece_id=piece_id,
            version_type=ScoreVersionType.raw,
            file_path=str(raw_path),
            is_default=True,
            created_at=now,
        )
        job = BackgroundJob(
            id=str(uuid.uuid4()),
            piece_id=piece_id,
            job_type="image_ocr_processing",
            status=JobStatus.succeeded,
            progress=100.0,
            result_data={
                "raw_score_version_id": raw_score_version.id,
                "processed_metadata": ocr_metadata,
                "ocr_metadata": ocr_metadata,
                "ocr_engine": ocr_result.engine_name,
                "ocr_confidence": ocr_result.confidence,
                "catalog_suggestions": ocr_result.catalog_suggestions,
                "warnings": ocr_result.warnings,
            },
            created_at=now,
            updated_at=now,
        )
        review_item = ReviewItem(
            id=str(uuid.uuid4()),
            piece_id=piece_id,
            item_type=ReviewItemType.score_candidate,
            title=f"Review OCR metadata for {title}",
            description=(
                "Review the OCR-derived catalog metadata before this image score "
                "is approved for student libraries."
            ),
            status="pending",
            candidate_data={
                "piece_title": title,
                "summary": "OCR metadata candidate prepared for parent review.",
                "confidence": ocr_result.confidence,
                "provenance": "ocr_text",
                "engine_name": ocr_result.engine_name,
                "processed_metadata": ocr_metadata,
                "ocr_metadata": ocr_metadata,
                "ocr_engine": ocr_result.engine_name,
                "ocr_confidence": ocr_result.confidence,
                "catalog_suggestions": ocr_result.catalog_suggestions,
                "warnings": ocr_result.warnings,
                "raw_score_version_id": raw_score_version.id,
            },
            created_at=now,
        )

        db.add(piece)
        db.add(raw_score_version)
        db.add(job)
        db.add(review_item)
        await db.commit()
        await db.refresh(piece)
        await db.refresh(raw_score_version)
        await db.refresh(review_item)
        await db.refresh(job)

        return ImportedPieceArtifacts(
            piece=piece,
            raw_score_version=raw_score_version,
            canonical_score_version=None,
            rendered_score_version=None,
            review_item=review_item,
            job=job,
            ocr_metadata=ocr_metadata,
            ocr_catalog_suggestions=ocr_result.catalog_suggestions,
        )

    async def import_book_pdf(
        self,
        db: AsyncSession,
        *,
        title: str,
        composer: str | None,
        file_name: str,
        file_bytes: bytes,
        split_hints: list[BookSplitHint],
        allow_title_override: bool = False,
        allow_composer_override: bool = False,
    ) -> ImportedBookArtifacts:
        processing_settings = ProcessingSettingsStore().load()
        _ensure_production_processing_ready(processing_settings)
        preprocessing_result: BookPreprocessingResult | None = None
        ocr_result = OcrMetadataExtractor(processing_settings).extract(
            file_name=file_name,
            file_bytes=file_bytes,
        )
        ocr_metadata = dict(ocr_result.metadata)
        ocr_title = _metadata_string(ocr_metadata, "title")
        ocr_composer = _metadata_string(ocr_metadata, "composer")
        if allow_title_override and ocr_title:
            title = ocr_title
        if allow_composer_override and ocr_composer:
            composer = ocr_composer

        if not split_hints:
            preprocessing_result = await asyncio.to_thread(
                partial(
                    BookPreprocessor(processing_settings).preprocess,
                    file_name=file_name,
                    file_bytes=file_bytes,
                )
            )
            preprocessed_title = _metadata_string(preprocessing_result.book_metadata, "title")
            preprocessed_composer = _metadata_string(preprocessing_result.book_metadata, "composer")
            if allow_title_override and preprocessed_title:
                title = preprocessed_title
            if allow_composer_override and preprocessed_composer:
                composer = preprocessed_composer
            split_hints = [
                BookSplitHint(
                    title=proposal.title,
                    page_start=proposal.page_start,
                    page_end=proposal.page_end,
                    composer=proposal.composer or composer,
                    primary_instrument=proposal.primary_instrument,
                    contained_piece_titles=proposal.contained_piece_titles,
                    multi_piece_page=proposal.multi_piece_page,
                    confidence=proposal.confidence,
                    validation_warnings=proposal.validation_warnings,
                )
                for proposal in preprocessing_result.split_proposals
            ]

        now = datetime.utcnow()
        book_id = str(uuid.uuid4())
        book_dir = settings.storage_path / "pieces" / book_id
        book_dir.mkdir(parents=True, exist_ok=True)
        raw_path = book_dir / f"raw_source{(Path(file_name).suffix or '.pdf').lower()}"
        raw_path.write_bytes(file_bytes)

        book_piece = Piece(
            id=book_id,
            title=title,
            composer=composer,
            file_name=file_name,
            status=PieceStatus.imported,
            created_at=now,
            updated_at=now,
        )
        raw_score_version = ScoreVersion(
            id=str(uuid.uuid4()),
            piece_id=book_id,
            version_type=ScoreVersionType.raw,
            file_path=str(raw_path),
            is_default=True,
            created_at=now,
        )
        job = BackgroundJob(
            id=str(uuid.uuid4()),
            piece_id=book_id,
            job_type="book_import",
            status=JobStatus.running,
            progress=10.0,
            created_at=now,
            updated_at=now,
        )
        db.add(book_piece)
        db.add(raw_score_version)
        db.add(job)
        await db.commit()
        await db.refresh(book_piece)
        await db.refresh(raw_score_version)
        await db.refresh(job)

        validation_warnings = list(ocr_result.warnings)
        if preprocessing_result is not None:
            validation_warnings.extend(preprocessing_result.warnings)
            if not split_hints:
                validation_warnings.append(
                    "No confident child-piece splits were detected from full-book OCR."
                )
        child_artifacts: list[ImportedPieceArtifacts] = []
        child_split_hints: list[BookSplitHint] = []
        for split_hint in split_hints:
            try:
                child_bytes = _extract_pdf_page_range(
                    file_bytes,
                    start_page=split_hint.page_start,
                    end_page=split_hint.page_end,
                )
            except ProcessingEngineError as exc:
                validation_warnings.append(
                    f"{split_hint.title}: could not extract pages "
                    f"{split_hint.page_start}-{split_hint.page_end}: {exc}"
                )
                continue

            child_artifact = await self.create_book_child_proposal(
                db,
                title=split_hint.title,
                composer=split_hint.composer or composer,
                file_name=_child_file_name(file_name, split_hint),
                file_bytes=child_bytes,
                source_book_id=book_id,
                source_page_start=split_hint.page_start,
                source_page_end=split_hint.page_end,
                split_confidence=split_hint.confidence,
                validation_warnings=split_hint.validation_warnings,
                primary_instrument=split_hint.primary_instrument,
                contained_piece_titles=split_hint.contained_piece_titles,
                multi_piece_page=split_hint.multi_piece_page,
            )
            child_artifacts.append(child_artifact)
            child_split_hints.append(split_hint)

        job.status = JobStatus.succeeded
        job.progress = 100.0
        job.result_data = {
            "source_book_id": book_id,
            "child_piece_ids": [artifact.piece.id for artifact in child_artifacts],
            "split_count": len(child_artifacts),
            "validation_warnings": validation_warnings,
            "book_preprocessing": preprocessing_result.to_dict() if preprocessing_result else None,
        }
        job.updated_at = datetime.utcnow()
        await db.commit()
        await db.refresh(job)
        return ImportedBookArtifacts(
            book_piece=book_piece,
            raw_score_version=raw_score_version,
            child_artifacts=child_artifacts,
            child_split_hints=child_split_hints,
            job=job,
            validation_warnings=validation_warnings,
            ocr_metadata=ocr_metadata,
            ocr_catalog_suggestions=ocr_result.catalog_suggestions,
            preprocessing_result=preprocessing_result,
        )

    async def create_book_child_proposal(
        self,
        db: AsyncSession,
        *,
        title: str,
        composer: str | None,
        file_name: str,
        file_bytes: bytes,
        source_book_id: str,
        source_page_start: int,
        source_page_end: int,
        split_confidence: float,
        validation_warnings: list[str],
        primary_instrument: str | None = None,
        contained_piece_titles: list[str] | None = None,
        multi_piece_page: bool = False,
    ) -> ImportedPieceArtifacts:
        now = datetime.utcnow()
        contained_piece_titles = contained_piece_titles or [title]
        piece_id = str(uuid.uuid4())
        piece_dir = settings.storage_path / "pieces" / piece_id
        piece_dir.mkdir(parents=True, exist_ok=True)
        raw_path = piece_dir / f"raw_source{(Path(file_name).suffix or '.pdf').lower()}"
        raw_path.write_bytes(file_bytes)

        piece = Piece(
            id=piece_id,
            title=title,
            composer=composer,
            file_name=file_name,
            status=PieceStatus.review_pending,
            created_at=now,
            updated_at=now,
        )
        raw_score_version = ScoreVersion(
            id=str(uuid.uuid4()),
            piece_id=piece_id,
            version_type=ScoreVersionType.raw,
            file_path=str(raw_path),
            is_default=True,
            created_at=now,
        )
        job = BackgroundJob(
            id=str(uuid.uuid4()),
            piece_id=piece_id,
            job_type="book_child_split_proposal",
            status=JobStatus.succeeded,
            progress=100.0,
            result_data={
                "raw_score_version_id": raw_score_version.id,
                "source_book_id": source_book_id,
                "source_page_start": source_page_start,
                "source_page_end": source_page_end,
                "split_confidence": split_confidence,
                "primary_instrument": primary_instrument,
                "contained_piece_titles": contained_piece_titles,
                "multi_piece_page": multi_piece_page,
                "validation_warnings": validation_warnings,
                "processing_stage": "split_review_needed",
            },
            created_at=now,
            updated_at=now,
        )
        review_item = ReviewItem(
            id=str(uuid.uuid4()),
            piece_id=piece_id,
            item_type=ReviewItemType.score_candidate,
            title=f"Review book split for {title}",
            description=(
                "Review this proposed piece split before sending the page range "
                "to score reconstruction."
            ),
            status="pending",
            candidate_data={
                "piece_title": title,
                "summary": (
                    "Book preprocessing proposed this child piece from the "
                    "Tesseract page-fact baseline. Approve or edit metadata "
                    "before OMR processing."
                ),
                "confidence": split_confidence,
                "provenance": "book_preprocessing_tesseract",
                "engine_name": "book_preprocessor",
                "processed_metadata": {},
                "catalog_metadata": {
                    "title": title,
                    "composer": composer,
                    "primary_instrument": primary_instrument,
                    "source_page_start": source_page_start,
                    "source_page_end": source_page_end,
                    "contained_piece_titles": contained_piece_titles,
                    "multi_piece_page": multi_piece_page,
                },
                "catalog_suggestions": [],
                "warnings": validation_warnings,
                "validation_warnings": validation_warnings,
                "raw_score_version_id": raw_score_version.id,
                "raw_content_type": "application/pdf",
                "source_book_id": source_book_id,
                "source_page_start": source_page_start,
                "source_page_end": source_page_end,
                "split_confidence": split_confidence,
                "contained_piece_titles": contained_piece_titles,
                "multi_piece_page": multi_piece_page,
                "processing_stage": "split_review_needed",
            },
            created_at=now,
        )
        db.add(piece)
        db.add(raw_score_version)
        db.add(job)
        db.add(review_item)
        await db.flush()
        return ImportedPieceArtifacts(
            piece=piece,
            raw_score_version=raw_score_version,
            canonical_score_version=None,
            rendered_score_version=None,
            review_item=review_item,
            job=job,
            ocr_metadata={},
            ocr_catalog_suggestions=[],
            musicxml_metadata={},
        )

    async def process_existing_pdf_job(
        self,
        db: AsyncSession,
        *,
        job: BackgroundJob,
    ) -> ImportedPieceArtifacts:
        await _raise_if_job_canceled(db, job)
        if not job.piece_id:
            raise ProcessingEngineError("Queued score processing job has no piece_id.")

        piece = await db.get(Piece, job.piece_id)
        if not piece:
            raise ProcessingEngineError("Queued score processing job references a missing piece.")

        result_data = dict(job.result_data or {})
        raw_score_version = await _load_raw_score_version(
            db,
            piece_id=piece.id,
            raw_score_version_id=result_data.get("raw_score_version_id"),
        )
        if not raw_score_version:
            raise ProcessingEngineError("Queued score processing job has no raw PDF version.")

        raw_path = Path(raw_score_version.file_path)
        if not raw_path.exists():
            raise ProcessingEngineError(f"Raw score file is missing: {raw_path}")
        if raw_path.suffix.lower() != ".pdf":
            raise ProcessingEngineError(
                "Queued score processing currently supports PDF files only."
            )

        processing_settings_store = ProcessingSettingsStore()
        processing_settings = processing_settings_store.load()
        if result_data.get("retry_mode") == "render_only":
            return await self._process_existing_render_job(
                db,
                job=job,
                piece=piece,
                raw_score_version=raw_score_version,
                result_data=result_data,
                processing_settings=processing_settings,
                processing_settings_store=processing_settings_store,
            )
        _ensure_production_processing_ready(processing_settings)
        piece_metadata = PieceStateService().metadata_for_piece(piece)
        catalog_metadata = piece_metadata.get("catalog_metadata") or {}
        if not isinstance(catalog_metadata, dict):
            catalog_metadata = {}
        catalog_metadata = _authoritative_catalog_metadata_for_processing(
            piece=piece,
            piece_metadata=piece_metadata,
            catalog_metadata=catalog_metadata,
            result_data=result_data,
        )
        primary_instrument = (
            _metadata_string(catalog_metadata, "primary_instrument")
            or piece_metadata.get("primary_instrument")
            or _metadata_string(result_data, "primary_instrument")
        )
        contained_piece_titles = _metadata_string_list(
            result_data, "contained_piece_titles"
        ) or _metadata_string_list(catalog_metadata, "contained_piece_titles")
        multi_piece_page = bool(
            result_data.get("multi_piece_page") or catalog_metadata.get("multi_piece_page")
        )
        file_bytes = raw_path.read_bytes()
        ocr_result = OcrMetadataExtractor(processing_settings).extract(
            file_name=piece.file_name,
            file_bytes=file_bytes,
        )
        ocr_metadata = dict(ocr_result.metadata)
        catalog_suggestions = _merge_catalog_suggestions(
            piece_metadata.get("catalog_suggestions"),
            ocr_result.catalog_suggestions,
        )
        warnings: list[str] = list(ocr_result.warnings)
        musicxml_metadata: dict[str, object] = {}
        processed_metadata: dict[str, object] = {}

        now = datetime.utcnow()
        piece_dir = raw_path.parent
        piece.status = PieceStatus.processing
        piece.updated_at = now
        job.status = JobStatus.running
        job.progress = 20.0
        job.error_message = None
        job.result_data = {**result_data, "raw_score_version_id": raw_score_version.id}
        job.updated_at = now
        await db.commit()

        omr_raw_path = raw_path
        omr_piece_paths: list[Path] = []
        omr_input_warnings: list[str] = []
        if multi_piece_page:
            omr_piece_paths, omr_input_warnings = await asyncio.to_thread(
                partial(
                    _prepare_multi_piece_omr_piece_pdfs,
                    raw_pdf_path=raw_path,
                    output_dir=piece_dir / "omr_inputs",
                    piece_titles=contained_piece_titles or [piece.title],
                )
            )
            if not omr_piece_paths:
                omr_raw_path, fallback_warnings = await asyncio.to_thread(
                    partial(
                        _prepare_multi_piece_omr_input_pdf,
                        raw_pdf_path=raw_path,
                        output_path=piece_dir / "omr_input.pdf",
                        piece_titles=contained_piece_titles or [piece.title],
                    )
                )
                omr_input_warnings.extend(fallback_warnings)
            warnings.extend(omr_input_warnings)

        canonical_path = piece_dir / "candidate.musicxml"
        job.progress = 35.0
        job.updated_at = datetime.utcnow()
        await db.commit()
        await _raise_if_job_canceled(db, job)
        if multi_piece_page and len(omr_piece_paths) > 1:
            musicxml_result = await asyncio.to_thread(
                partial(
                    MusicXmlEngine().generate_multi_piece_segments,
                    raw_pdf_paths=omr_piece_paths,
                    output_path=canonical_path,
                    title=piece.title,
                    composer=piece.composer,
                    primary_instrument=primary_instrument,
                    contained_piece_titles=contained_piece_titles,
                    processing_settings=processing_settings,
                )
            )
        else:
            musicxml_result = await asyncio.to_thread(
                partial(
                    MusicXmlEngine().generate,
                    raw_pdf_path=omr_raw_path,
                    output_path=canonical_path,
                    title=piece.title,
                    composer=piece.composer,
                    primary_instrument=primary_instrument,
                    contained_piece_titles=contained_piece_titles,
                    multi_piece_page=multi_piece_page,
                    processing_settings=processing_settings,
                )
            )
        await _raise_if_job_canceled(db, job)
        warnings.extend(musicxml_result.warnings)
        musicxml_metadata = dict(musicxml_result.metadata)
        processed_metadata = _merge_metadata(ocr_metadata, musicxml_metadata)
        if primary_instrument:
            processed_metadata["primary_instrument"] = primary_instrument

        if not piece.composer and isinstance(processed_metadata.get("composer"), str):
            piece.composer = processed_metadata["composer"]
        if not piece.key_signature and isinstance(processed_metadata.get("key_signature"), str):
            piece.key_signature = processed_metadata["key_signature"]
        if not piece.tempo and isinstance(processed_metadata.get("tempo"), str):
            piece.tempo = processed_metadata["tempo"]

        rendered_path = piece_dir / "candidate_review.pdf"
        job.progress = 65.0
        job.updated_at = datetime.utcnow()
        await db.commit()
        await _raise_if_job_canceled(db, job)
        render_error: Exception | None = None
        try:
            render_result = await asyncio.to_thread(
                partial(
                    MuseScoreRenderEngine().render,
                    canonical_path=musicxml_result.file_path,
                    raw_pdf_path=raw_path,
                    output_pdf_path=rendered_path,
                    processing_settings=processing_settings,
                )
            )
        except (OSError, ProcessingEngineError, subprocess.TimeoutExpired) as exc:
            render_error = exc
            render_result = _blocked_render_result(rendered_path, exc)
        await _raise_if_job_canceled(db, job)
        _repair_multi_piece_review_pdf_titles(
            render_result,
            contained_piece_titles=contained_piece_titles,
            multi_piece_page=multi_piece_page,
        )
        _attach_spacing_normalization_diagnostics(render_result, musicxml_metadata)
        warnings.extend(render_result.warnings)
        raw_page_count = _pdf_page_count(raw_path)
        warnings.extend(
            _score_candidate_review_warnings(
                raw_pdf_path=raw_path,
                raw_page_count=raw_page_count,
                render_result=render_result,
                musicxml_provenance=musicxml_result.provenance,
                contained_piece_titles=contained_piece_titles,
                multi_piece_page=multi_piece_page,
            )
        )
        await _raise_if_job_canceled(db, job)
        try:
            alternative_candidate_artifacts = await asyncio.to_thread(
                partial(
                    _render_alternative_omr_candidate_artifacts,
                    piece_dir=piece_dir,
                    raw_path=raw_path,
                    selected_canonical_path=musicxml_result.file_path,
                    selected_engine_name=musicxml_result.engine_name,
                    title=piece.title,
                    composer=piece.composer,
                    primary_instrument=primary_instrument,
                    contained_piece_titles=contained_piece_titles,
                    multi_piece_page=multi_piece_page,
                    ocr_metadata=ocr_metadata,
                    processing_settings=processing_settings,
                    raw_page_count=raw_page_count,
                    attempts=musicxml_metadata.get("omr_attempts"),
                )
            )
        except (OSError, ProcessingEngineError, subprocess.TimeoutExpired) as exc:
            alternative_candidate_artifacts = []
            warnings.append(f"Alternative OMR candidate preparation failed: {exc}")
        await _raise_if_job_canceled(db, job)

        canonical_score_version = ScoreVersion(
            id=str(uuid.uuid4()),
            piece_id=piece.id,
            version_type=ScoreVersionType.reconstructed_candidate,
            file_path=str(musicxml_result.file_path),
            is_default=False,
            created_at=now,
        )
        rendered_score_version = ScoreVersion(
            id=str(uuid.uuid4()),
            piece_id=piece.id,
            version_type=ScoreVersionType.reconstructed_candidate,
            file_path=str(render_result.file_path),
            is_default=False,
            created_at=now,
        )
        omr_candidates = [
            _selected_omr_candidate_payload(
                candidate_id="selected_best",
                label=f"Best: {_omr_candidate_label(musicxml_result.engine_name, None)}",
                raw_score_version_id=raw_score_version.id,
                canonical_score_version_id=canonical_score_version.id,
                rendered_score_version_id=rendered_score_version.id,
                musicxml_result=musicxml_result,
                musicxml_metadata=musicxml_metadata,
                processed_metadata=processed_metadata,
                render_result=render_result,
                warnings=warnings,
                selected=True,
            )
        ]
        for alternative_artifact in alternative_candidate_artifacts:
            alternative_canonical_score_version = ScoreVersion(
                id=str(uuid.uuid4()),
                piece_id=piece.id,
                version_type=ScoreVersionType.reconstructed_candidate,
                file_path=str(alternative_artifact.canonical_path),
                is_default=False,
                created_at=now,
            )
            alternative_rendered_score_version = ScoreVersion(
                id=str(uuid.uuid4()),
                piece_id=piece.id,
                version_type=ScoreVersionType.reconstructed_candidate,
                file_path=str(alternative_artifact.rendered_path),
                is_default=False,
                created_at=now,
            )
            db.add(alternative_canonical_score_version)
            db.add(alternative_rendered_score_version)
            omr_candidates.append(
                _omr_candidate_payload_from_artifact(
                    artifact=alternative_artifact,
                    raw_score_version_id=raw_score_version.id,
                    canonical_score_version_id=alternative_canonical_score_version.id,
                    rendered_score_version_id=alternative_rendered_score_version.id,
                    selected=False,
                )
            )
        review_item = ReviewItem(
            id=str(uuid.uuid4()),
            piece_id=piece.id,
            item_type=ReviewItemType.score_candidate,
            title=f"Review reconstructed score for {piece.title}",
            description=(
                "Compare the rendered reconstruction against the original PDF "
                "and approve it only if the default score is ready for students."
            ),
            status="pending",
            candidate_data={
                "piece_title": piece.title,
                "summary": "Async server processing candidate prepared for parent review.",
                "confidence": musicxml_result.confidence,
                "provenance": musicxml_result.provenance,
                "engine_name": musicxml_result.engine_name,
                "engine_version": musicxml_result.engine_version,
                "processed_metadata": processed_metadata,
                "catalog_metadata": catalog_metadata,
                "ocr_metadata": ocr_metadata,
                "ocr_engine": ocr_result.engine_name,
                "ocr_confidence": ocr_result.confidence,
                "catalog_suggestions": catalog_suggestions,
                "renderer_name": render_result.renderer_name,
                "renderer_version": render_result.renderer_version,
                "renderer_provenance": render_result.provenance,
                "render_validation_status": render_result.validation_status,
                "render_validation_error": render_result.validation_error,
                "rendered_file_size_bytes": render_result.file_size_bytes,
                "rendered_page_count": render_result.page_count,
                "render_diagnostics": render_result.diagnostics,
                "raw_page_count": raw_page_count,
                "omr_input_file_path": str(omr_raw_path) if omr_raw_path != raw_path else None,
                "omr_input_file_paths": [str(path) for path in omr_piece_paths] or None,
                "omr_input_page_count": _pdf_page_count(omr_raw_path)
                if omr_raw_path != raw_path
                else len(omr_piece_paths) or None,
                "conversion_review_required": True,
                "warnings": warnings,
                "raw_score_version_id": raw_score_version.id,
                "score_version_id": rendered_score_version.id,
                "canonical_score_version_id": canonical_score_version.id,
                "selected_omr_candidate_id": "selected_best",
                "omr_candidates": omr_candidates,
                "source_review_item_id": result_data.get("source_review_item_id"),
                "source_book_id": result_data.get("source_book_id")
                or catalog_metadata.get("source_book_id"),
                "contained_piece_titles": result_data.get("contained_piece_titles")
                or catalog_metadata.get("contained_piece_titles"),
                "multi_piece_page": result_data.get("multi_piece_page")
                or catalog_metadata.get("multi_piece_page"),
                "processing_stage": "candidate_review_needed",
            },
            created_at=now,
        )

        db.add(canonical_score_version)
        db.add(rendered_score_version)
        db.add(review_item)

        piece.status = PieceStatus.review_pending
        piece.updated_at = datetime.utcnow()
        job.status = (
            JobStatus.succeeded if render_result.validation_status == "valid" else JobStatus.failed
        )
        job.progress = 100.0
        job.error_message = str(render_error) if render_error else None
        job.result_data = {
            **result_data,
            "raw_score_version_id": raw_score_version.id,
            "candidate_review_item_id": review_item.id,
            "rendered_score_version_id": rendered_score_version.id,
            "canonical_score_version_id": canonical_score_version.id,
            "selected_omr_candidate_id": "selected_best",
            "omr_candidate_count": len(omr_candidates),
            "engine_name": musicxml_result.engine_name,
            "engine_version": musicxml_result.engine_version,
            "processed_metadata": processed_metadata,
            "catalog_metadata": catalog_metadata,
            "ocr_metadata": ocr_metadata,
            "ocr_engine": ocr_result.engine_name,
            "ocr_confidence": ocr_result.confidence,
            "catalog_suggestions": catalog_suggestions,
            "renderer_name": render_result.renderer_name,
            "renderer_version": render_result.renderer_version,
            "render_validation_status": render_result.validation_status,
            "render_validation_error": render_result.validation_error,
            "rendered_file_size_bytes": render_result.file_size_bytes,
            "rendered_page_count": render_result.page_count,
            "render_diagnostics": render_result.diagnostics,
            "raw_page_count": raw_page_count,
            "omr_input_file_path": str(omr_raw_path) if omr_raw_path != raw_path else None,
            "omr_input_file_paths": [str(path) for path in omr_piece_paths] or None,
            "omr_input_page_count": _pdf_page_count(omr_raw_path)
            if omr_raw_path != raw_path
            else len(omr_piece_paths) or None,
            "conversion_review_required": True,
            "warnings": warnings,
            "contained_piece_titles": result_data.get("contained_piece_titles")
            or catalog_metadata.get("contained_piece_titles"),
            "multi_piece_page": result_data.get("multi_piece_page")
            or catalog_metadata.get("multi_piece_page"),
            "processing_stage": "candidate_review_needed",
        }
        job.updated_at = datetime.utcnow()
        processing_settings_store.record_last_error(str(render_error) if render_error else None)

        await db.commit()
        await db.refresh(piece)
        await db.refresh(raw_score_version)
        await db.refresh(canonical_score_version)
        await db.refresh(rendered_score_version)
        await db.refresh(review_item)
        await db.refresh(job)

        return ImportedPieceArtifacts(
            piece=piece,
            raw_score_version=raw_score_version,
            canonical_score_version=canonical_score_version,
            rendered_score_version=rendered_score_version,
            review_item=review_item,
            job=job,
            ocr_metadata=ocr_metadata,
            ocr_catalog_suggestions=ocr_result.catalog_suggestions,
            musicxml_metadata=musicxml_metadata,
        )

    async def _process_existing_render_job(
        self,
        db: AsyncSession,
        *,
        job: BackgroundJob,
        piece: Piece,
        raw_score_version: ScoreVersion,
        result_data: dict[str, object],
        processing_settings: dict[str, object],
        processing_settings_store: ProcessingSettingsStore,
    ) -> ImportedPieceArtifacts:
        canonical_id = result_data.get("canonical_score_version_id")
        rendered_id = result_data.get("rendered_score_version_id")
        if not isinstance(canonical_id, str) or not isinstance(rendered_id, str):
            raise ProcessingEngineError(
                "Render-only retry requires existing canonical and rendered score versions."
            )

        canonical_score_version = await db.get(ScoreVersion, canonical_id)
        rendered_score_version = await db.get(ScoreVersion, rendered_id)
        if not canonical_score_version or not rendered_score_version:
            raise ProcessingEngineError("Render-only retry references missing score versions.")

        canonical_path = Path(canonical_score_version.file_path)
        rendered_path = Path(rendered_score_version.file_path)
        raw_path = Path(raw_score_version.file_path)
        if not canonical_path.exists():
            raise ProcessingEngineError(f"MusicXML candidate is missing: {canonical_path}")
        if not raw_path.exists():
            raise ProcessingEngineError(f"Raw score file is missing: {raw_path}")

        now = datetime.utcnow()
        piece.status = PieceStatus.processing
        piece.updated_at = now
        job.status = JobStatus.running
        job.progress = 35.0
        job.error_message = None
        job.result_data = {
            **result_data,
            "retry_mode": "render_only",
            "render_retry_started_at": now.isoformat(),
        }
        job.updated_at = now
        await db.commit()
        await _raise_if_job_canceled(db, job)

        render_error: Exception | None = None
        try:
            render_result = await asyncio.to_thread(
                partial(
                    MuseScoreRenderEngine().render,
                    canonical_path=canonical_path,
                    raw_pdf_path=raw_path,
                    output_pdf_path=rendered_path,
                    processing_settings=processing_settings,
                )
            )
        except (OSError, ProcessingEngineError, subprocess.TimeoutExpired) as exc:
            render_error = exc
            render_result = _blocked_render_result(rendered_path, exc)
        await _raise_if_job_canceled(db, job)

        review_item = await _review_item_for_render_retry(
            db,
            piece_id=piece.id,
            result_data=result_data,
            canonical_score_version_id=canonical_score_version.id,
            rendered_score_version_id=rendered_score_version.id,
        )
        if review_item:
            candidate_data = dict(review_item.candidate_data or {})
            _repair_multi_piece_review_pdf_titles(
                render_result,
                contained_piece_titles=[
                    title
                    for title in candidate_data.get("contained_piece_titles") or []
                    if isinstance(title, str)
                ],
                multi_piece_page=bool(candidate_data.get("multi_piece_page")),
            )
            existing_warnings = [
                warning
                for warning in candidate_data.get("warnings") or []
                if isinstance(warning, str)
                and "MuseScore did not produce a usable review PDF" not in warning
                and "MusicXML was generated, but MuseScore did not produce" not in warning
            ]
            candidate_data["renderer_name"] = render_result.renderer_name
            candidate_data["renderer_version"] = render_result.renderer_version
            candidate_data["renderer_provenance"] = render_result.provenance
            candidate_data["render_validation_status"] = render_result.validation_status
            candidate_data["render_validation_error"] = render_result.validation_error
            candidate_data["rendered_file_size_bytes"] = render_result.file_size_bytes
            candidate_data["rendered_page_count"] = render_result.page_count
            candidate_data["render_diagnostics"] = render_result.diagnostics
            candidate_data["render_retry_completed_at"] = datetime.utcnow().isoformat()
            candidate_data["warnings"] = sorted(
                set(existing_warnings + list(render_result.warnings))
            )
            review_item.candidate_data = candidate_data

        job.status = (
            JobStatus.succeeded if render_result.validation_status == "valid" else JobStatus.failed
        )
        job.progress = 100.0
        job.error_message = str(render_error) if render_error else None
        job.result_data = {
            **result_data,
            "retry_mode": "render_only",
            "render_retry_completed_at": datetime.utcnow().isoformat(),
            "raw_score_version_id": raw_score_version.id,
            "canonical_score_version_id": canonical_score_version.id,
            "rendered_score_version_id": rendered_score_version.id,
            "candidate_review_item_id": review_item.id if review_item else None,
            "renderer_name": render_result.renderer_name,
            "renderer_version": render_result.renderer_version,
            "render_validation_status": render_result.validation_status,
            "render_validation_error": render_result.validation_error,
            "rendered_file_size_bytes": render_result.file_size_bytes,
            "rendered_page_count": render_result.page_count,
            "render_diagnostics": render_result.diagnostics,
            "warnings": list(render_result.warnings),
            "processing_stage": "candidate_review_needed",
        }
        job.updated_at = datetime.utcnow()
        piece.status = PieceStatus.review_pending
        piece.updated_at = datetime.utcnow()
        processing_settings_store.record_last_error(str(render_error) if render_error else None)

        await db.commit()
        await db.refresh(piece)
        await db.refresh(raw_score_version)
        await db.refresh(canonical_score_version)
        await db.refresh(rendered_score_version)
        if review_item:
            await db.refresh(review_item)
        await db.refresh(job)

        return ImportedPieceArtifacts(
            piece=piece,
            raw_score_version=raw_score_version,
            canonical_score_version=canonical_score_version,
            rendered_score_version=rendered_score_version,
            review_item=review_item,
            job=job,
        )


async def _review_item_for_render_retry(
    db: AsyncSession,
    *,
    piece_id: str,
    result_data: dict[str, object],
    canonical_score_version_id: str,
    rendered_score_version_id: str,
) -> ReviewItem | None:
    review_item_id = result_data.get("candidate_review_item_id") or result_data.get(
        "review_item_id"
    )
    if isinstance(review_item_id, str):
        review_item = await db.get(ReviewItem, review_item_id)
        if review_item and review_item.piece_id == piece_id:
            return review_item

    result = await db.execute(
        select(ReviewItem).where(
            ReviewItem.piece_id == piece_id,
            ReviewItem.status == "pending",
        )
    )
    for review_item in result.scalars().all():
        candidate_data = dict(review_item.candidate_data or {})
        if candidate_data.get("canonical_score_version_id") != canonical_score_version_id:
            continue
        if candidate_data.get("score_version_id") != rendered_score_version_id:
            continue
        return review_item
    return None


async def _raise_if_job_canceled(db: AsyncSession, job: BackgroundJob) -> None:
    await db.refresh(job)
    if job.status != JobStatus.canceled:
        return
    if job.piece_id:
        piece = await db.get(Piece, job.piece_id)
        if piece and piece.status == PieceStatus.processing:
            piece.status = PieceStatus.imported
            piece.updated_at = datetime.utcnow()
            await db.commit()
    raise JobCanceledError(f"Job {job.id} was canceled.")


def _extract_pdf_page_range(
    file_bytes: bytes,
    *,
    start_page: int,
    end_page: int,
) -> bytes:
    if end_page < start_page:
        raise ProcessingEngineError("page_end must be greater than or equal to page_start.")
    try:
        from pypdf import PdfReader, PdfWriter
    except ImportError as exc:
        raise ProcessingEngineError(
            "pypdf is required to extract child PDFs from book imports."
        ) from exc

    reader = PdfReader(BytesIO(file_bytes))
    page_count = len(reader.pages)
    if start_page > page_count or end_page > page_count:
        raise ProcessingEngineError(
            f"page range {start_page}-{end_page} exceeds PDF page count {page_count}."
        )

    writer = PdfWriter()
    for page_index in range(start_page - 1, end_page):
        writer.add_page(reader.pages[page_index])
    output = BytesIO()
    writer.write(output)
    return output.getvalue()


def _prepare_multi_piece_omr_input_pdf(
    *,
    raw_pdf_path: Path,
    output_path: Path,
    piece_titles: list[str],
) -> tuple[Path, list[str]]:
    clean_titles = [title.strip() for title in piece_titles if title and title.strip()]
    if len(clean_titles) < 2:
        return raw_pdf_path, []

    crop_pages, split_strategy, warnings = _multi_piece_crop_pages(
        raw_pdf_path=raw_pdf_path,
        clean_titles=clean_titles,
    )
    if not crop_pages:
        return raw_pdf_path, warnings

    output_path.parent.mkdir(parents=True, exist_ok=True)
    first, *rest = crop_pages
    first.save(
        output_path,
        "PDF",
        save_all=True,
        append_images=rest,
        resolution=144,
    )
    return output_path, [
        *warnings,
        "Multiple pieces were detected on one source page; Audiveris used a "
        f"{len(crop_pages)}-page OMR crop input ({split_strategy}) so each "
        "short piece could be reconstructed separately.",
    ]


def _prepare_multi_piece_omr_piece_pdfs(
    *,
    raw_pdf_path: Path,
    output_dir: Path,
    piece_titles: list[str],
) -> tuple[list[Path], list[str]]:
    clean_titles = [title.strip() for title in piece_titles if title and title.strip()]
    if len(clean_titles) < 2:
        return [], []

    crop_pages, split_strategy, warnings = _multi_piece_crop_pages(
        raw_pdf_path=raw_pdf_path,
        clean_titles=clean_titles,
    )
    if not crop_pages:
        return [], warnings

    output_dir.mkdir(parents=True, exist_ok=True)
    output_paths: list[Path] = []
    for index, crop_page in enumerate(crop_pages):
        output_path = output_dir / f"omr_piece_{index + 1:02}.pdf"
        crop_page.save(output_path, "PDF", resolution=144)
        output_paths.append(output_path)
    return output_paths, [
        *warnings,
        "Multiple pieces were detected on one source page; each crop was saved "
        f"as a separate OMR input ({split_strategy}) before MusicXML merge.",
    ]


def _multi_piece_crop_pages(
    *,
    raw_pdf_path: Path,
    clean_titles: list[str],
):
    raw_page_count = _pdf_page_count(raw_pdf_path)
    if raw_page_count != 1:
        return (
            [],
            "",
            [
                "Multiple pieces were detected, but OMR crop splitting only supports "
                "single-page child proposals right now."
            ],
        )

    try:
        import pypdfium2 as pdfium
    except ImportError:
        return (
            [],
            "",
            ["Multiple pieces were detected, but pypdfium2 is unavailable for OMR crop splitting."],
        )

    try:
        document = pdfium.PdfDocument(str(raw_pdf_path))
        try:
            page = document[0]
            try:
                bitmap = page.render(scale=2)
                image = bitmap.to_pil().convert("RGB")
            finally:
                page.close()
        finally:
            document.close()
    except Exception as exc:  # pragma: no cover - PDF renderer failures vary by platform
        return [], "", [f"Could not prepare multi-piece OMR crop input: {exc}"]

    boundaries = _multi_piece_staff_split_boundaries(
        _staff_line_centers(image),
        page_height=image.size[1],
        piece_count=len(clean_titles),
    )
    split_strategy = "staff-gap"
    if len(boundaries) != len(clean_titles) - 1:
        if len(clean_titles) == 2:
            boundaries = [image.size[1] // 2]
            split_strategy = "equal-half-fallback"
        else:
            return (
                [],
                "",
                [
                    "Multiple pieces were detected, but no reliable staff-line split boundary "
                    "was found. Audiveris used the full shared page."
                ],
            )

    refined_boundaries = _refine_multi_piece_boundaries_for_heading_text(
        image,
        boundaries,
        piece_count=len(clean_titles),
    )
    if refined_boundaries != boundaries:
        boundaries = refined_boundaries
        split_strategy = f"{split_strategy}+heading-safe"

    crop_edges = [0, *boundaries, image.size[1]]
    crop_pages = []
    minimum_height = max(80, image.size[1] // 10)
    for index in range(len(crop_edges) - 1):
        top = max(0, crop_edges[index])
        bottom = min(image.size[1], crop_edges[index + 1])
        if bottom - top < minimum_height:
            return (
                [],
                "",
                [
                    "Multiple pieces were detected, but the calculated OMR crop was too small. "
                    "Audiveris used the full shared page."
                ],
            )
        crop_pages.append(image.crop((0, top, image.size[0], bottom)))

    return crop_pages, split_strategy, []


def _refine_multi_piece_boundaries_for_heading_text(
    image,
    boundaries: list[int],
    *,
    piece_count: int,
) -> list[int]:
    """Move a two-piece split above a heading if the staff gap cuts through it."""
    if piece_count != 2 or len(boundaries) != 1:
        return boundaries

    split_y = boundaries[0]
    page_width, page_height = image.size
    if page_width <= 0 or page_height <= 0:
        return boundaries

    min_segment_height = max(80, page_height // 10)
    search_top = max(0, split_y - int(page_height * 0.08))
    search_bottom = min(page_height, split_y + int(page_height * 0.04))
    near_padding = max(8, int(page_height * 0.015))
    title_padding = max(8, int(page_height * 0.008))

    for start_y, end_y, max_dark_ratio in _dark_content_row_groups(
        image,
        min_dark_ratio=0.002,
        max_row_gap=2,
    ):
        if end_y < search_top or start_y > search_bottom:
            continue
        group_height = end_y - start_y + 1
        if group_height < max(8, page_height // 220):
            continue
        if group_height > page_height * 0.045:
            continue
        if max_dark_ratio < 0.02 or max_dark_ratio > 0.25:
            continue
        if not (start_y <= split_y <= end_y + near_padding):
            continue

        adjusted_y = start_y - title_padding
        if adjusted_y < min_segment_height or page_height - adjusted_y < min_segment_height:
            return boundaries
        if adjusted_y >= split_y:
            return boundaries
        return [adjusted_y]

    return boundaries


def _multi_piece_staff_split_boundaries(
    line_centers: list[int],
    *,
    page_height: int,
    piece_count: int,
) -> list[int]:
    if piece_count < 2 or page_height <= 0 or len(line_centers) < piece_count * 5:
        return []

    centers = sorted(set(line_centers))
    gaps: list[tuple[int, int]] = []
    for previous_y, next_y in zip(centers, centers[1:]):
        gap = next_y - previous_y
        midpoint = (previous_y + next_y) // 2
        if gap < 24:
            continue
        if midpoint < page_height * 0.12 or midpoint > page_height * 0.88:
            continue
        gaps.append((gap, midpoint))

    boundaries: list[int] = []
    for split_index in range(1, piece_count):
        desired = int(page_height * split_index / piece_count)
        available = [
            (gap, midpoint)
            for gap, midpoint in gaps
            if all(abs(midpoint - existing) > page_height * 0.12 for existing in boundaries)
        ]
        if not available:
            return []
        gap, midpoint = max(
            available,
            key=lambda item: item[0] - abs(item[1] - desired) * 0.12,
        )
        if gap < page_height * 0.035:
            return []
        boundaries.append(midpoint)

    boundaries.sort()
    if any(
        bottom - top < page_height * 0.15
        for top, bottom in zip([0, *boundaries], [*boundaries, page_height])
    ):
        return []
    return boundaries


def _dark_content_row_groups(
    image,
    *,
    min_dark_ratio: float,
    max_row_gap: int,
) -> list[tuple[int, int, float]]:
    grayscale = image.convert("L")
    width, height = grayscale.size
    pixels = grayscale.load()
    groups: list[tuple[int, int, float]] = []
    start: int | None = None
    previous_y: int | None = None
    max_ratio = 0.0

    for y in range(height):
        row_dark = 0
        for x in range(width):
            if pixels[x, y] < 110:
                row_dark += 1
        dark_ratio = row_dark / max(1, width)
        if dark_ratio < min_dark_ratio:
            continue
        if start is None or previous_y is None or y - previous_y > max_row_gap:
            if start is not None and previous_y is not None:
                groups.append((start, previous_y, max_ratio))
            start = y
            max_ratio = dark_ratio
        else:
            max_ratio = max(max_ratio, dark_ratio)
        previous_y = y

    if start is not None and previous_y is not None:
        groups.append((start, previous_y, max_ratio))
    return groups


def _staff_line_centers(image) -> list[int]:
    grayscale = image.convert("L")
    width, height = grayscale.size
    pixels = grayscale.load()
    dark_rows: list[int] = []
    for y in range(height):
        row_dark = 0
        for x in range(width):
            if pixels[x, y] < 110:
                row_dark += 1
        if row_dark / max(1, width) >= 0.11:
            dark_rows.append(y)

    groups: list[int] = []
    start: int | None = None
    previous_y: int | None = None
    for y in dark_rows:
        if start is None or previous_y is None or y - previous_y > 2:
            if start is not None and previous_y is not None:
                groups.append((start + previous_y) // 2)
            start = y
        previous_y = y
    if start is not None and previous_y is not None:
        groups.append((start + previous_y) // 2)
    return groups


async def _load_raw_score_version(
    db: AsyncSession,
    *,
    piece_id: str,
    raw_score_version_id: object,
) -> ScoreVersion | None:
    if isinstance(raw_score_version_id, str) and raw_score_version_id.strip():
        result = await db.execute(
            select(ScoreVersion).where(
                ScoreVersion.id == raw_score_version_id,
                ScoreVersion.piece_id == piece_id,
                ScoreVersion.version_type == ScoreVersionType.raw,
            )
        )
        raw_score_version = result.scalar_one_or_none()
        if raw_score_version:
            return raw_score_version

    result = await db.execute(
        select(ScoreVersion)
        .where(
            ScoreVersion.piece_id == piece_id,
            ScoreVersion.version_type == ScoreVersionType.raw,
        )
        .order_by(ScoreVersion.created_at.asc())
        .limit(1)
    )
    return result.scalar_one_or_none()


def _blocked_render_result(rendered_path: Path, exc: Exception) -> RenderResult:
    message = str(exc)
    diagnostics = getattr(exc, "diagnostics", None)
    if not isinstance(diagnostics, dict):
        diagnostics = {}
    file_size_bytes = None
    if rendered_path.exists():
        try:
            file_size_bytes = rendered_path.stat().st_size
        except OSError:
            file_size_bytes = None
    return RenderResult(
        file_path=rendered_path,
        renderer_name="musescore_render_blocked",
        renderer_version=None,
        provenance="render_blocked",
        warnings=[
            f"MusicXML was generated, but MuseScore did not produce a usable review PDF: {message}"
        ],
        validation_status="render_failed",
        validation_error=message,
        file_size_bytes=file_size_bytes,
        page_count=None,
        diagnostics=diagnostics,
    )


def _score_candidate_review_warnings(
    *,
    raw_pdf_path: Path,
    raw_page_count: int | None,
    render_result: RenderResult,
    musicxml_provenance: str,
    contained_piece_titles: list[str] | None,
    multi_piece_page: bool,
) -> list[str]:
    warnings: list[str] = []
    if musicxml_provenance.startswith("audiveris_omr"):
        warnings.append(
            "Audiveris produced an editable reconstruction candidate. Verify notes, "
            "rhythm, fingering, lyrics/text, and layout against the original before "
            "approving it as the student default."
        )
    if multi_piece_page or len(contained_piece_titles or []) > 1:
        warnings.append(
            "Multiple pieces share this source page. Confirm every title and section "
            "is present in the MuseScore candidate before approving."
        )
        raw_line_count = _pdf_horizontal_line_count(raw_pdf_path)
        rendered_line_count = _pdf_horizontal_line_count(render_result.file_path)
        if (
            raw_line_count is not None
            and rendered_line_count is not None
            and rendered_line_count < raw_line_count * 0.85
        ):
            warnings.append(
                f"The rendered MuseScore candidate has fewer detected staff-line groups "
                f"({rendered_line_count}) than the source page ({raw_line_count}). "
                "Confirm no systems or measures were dropped before approving."
            )
    if (
        raw_pdf_path.suffix.lower() == ".pdf"
        and raw_page_count is not None
        and render_result.page_count is not None
        and render_result.page_count < raw_page_count
    ):
        warnings.append(
            f"The rendered candidate has {render_result.page_count} page(s), but the "
            f"source split has {raw_page_count}. Confirm no source pages were lost."
        )
    return warnings


def _pdf_page_count(path: Path) -> int | None:
    if path.suffix.lower() != ".pdf" or not path.exists():
        return None
    try:
        from pypdf import PdfReader

        return len(PdfReader(str(path)).pages)
    except Exception:
        return None


def _pdf_horizontal_line_count(path: Path) -> int | None:
    if path.suffix.lower() != ".pdf" or not path.exists():
        return None
    try:
        import pypdfium2 as pdfium

        document = pdfium.PdfDocument(str(path))
        try:
            if len(document) < 1:
                return None
            line_count = 0
            for page_index in range(min(len(document), 4)):
                page = document[page_index]
                try:
                    bitmap = page.render(scale=2)
                    image = bitmap.to_pil()
                    line_count += int(_analyze_page_image(image)["horizontal_line_count"])
                finally:
                    page.close()
            return line_count if line_count > 0 else None
        finally:
            document.close()
    except Exception:
        return None


def _child_file_name(source_file_name: str, split_hint: BookSplitHint) -> str:
    safe_title = "".join(
        char if char.isalnum() or char in {" ", "-", "_"} else " " for char in split_hint.title
    )
    safe_title = "_".join(safe_title.split()) or "child_piece"
    suffix = Path(source_file_name).suffix or ".pdf"
    return f"{safe_title}{suffix.lower()}"


def _metadata_string(metadata: dict[str, object], key: str) -> str | None:
    value = metadata.get(key)
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None


def _metadata_string_list(metadata: dict[str, object], key: str) -> list[str]:
    value = metadata.get(key)
    if not isinstance(value, list):
        return []
    return [item.strip() for item in value if isinstance(item, str) and item.strip()]


def _ensure_production_processing_ready(processing_settings: dict[str, object]) -> None:
    if not processing_settings.get("production_mode"):
        return

    missing = []
    for name, key, fallbacks in (
        ("Audiveris", "audiveris_cli_path", ("audiveris",)),
        ("MuseScore Studio", "musescore_cli_path", ("musescore", "mscore", "MuseScore4")),
        ("Tesseract OCR", "ocr_cli_path", ("tesseract",)),
    ):
        status = executable_status(
            name=name,
            configured_path=processing_settings.get(key),  # type: ignore[arg-type]
            fallback_names=fallbacks,
        )
        if not status.available:
            missing.append(name)

    if missing:
        raise ProcessingEngineError(
            "Production processing requires configured real tools: " + ", ".join(missing) + "."
        )


def _merge_metadata(
    ocr_metadata: dict[str, object],
    musicxml_metadata: dict[str, object],
) -> dict[str, object]:
    merged = dict(ocr_metadata)
    for key, value in musicxml_metadata.items():
        if value not in (None, "", []):
            merged[key] = value
    return merged


def _attach_spacing_normalization_diagnostics(
    render_result: RenderResult,
    musicxml_metadata: dict[str, object],
) -> None:
    if not musicxml_metadata.get("spacing_normalization_applied"):
        return
    diagnostics = dict(render_result.diagnostics or {})
    diagnostics["spacing_normalization_applied"] = True
    diagnostics["spacing_normalization_profile"] = musicxml_metadata.get(
        "spacing_normalization_profile"
    )
    diagnostics["spacing_normalization_changes"] = musicxml_metadata.get(
        "spacing_normalization_changes"
    )
    render_result.diagnostics = diagnostics


def _repair_multi_piece_review_pdf_titles(
    render_result: RenderResult,
    *,
    contained_piece_titles: list[str] | None,
    multi_piece_page: bool,
) -> None:
    """Center the second title in a two-piece, single-page parent review PDF."""

    piece_titles = [title.strip() for title in contained_piece_titles or [] if title.strip()]
    if (
        not multi_piece_page
        or len(piece_titles) != 2
        or render_result.validation_status != "valid"
        or render_result.page_count != 1
        or render_result.provenance != "musescore_render"
    ):
        return

    rendered_path = render_result.file_path
    if not rendered_path.exists() or rendered_path.suffix.lower() != ".pdf":
        return

    try:
        _overlay_centered_second_piece_title(rendered_path, piece_titles[1])
        validation = validate_rendered_pdf(rendered_path, strict=True)
    except Exception as exc:  # pragma: no cover - pypdf failures vary by file
        render_result.warnings.append(
            f"Could not center the shared-page title '{piece_titles[1]}' in the review PDF: {exc}"
        )
        return

    render_result.validation_status = validation["validation_status"]
    render_result.validation_error = validation["validation_error"]
    render_result.file_size_bytes = validation["file_size_bytes"]
    render_result.page_count = validation["page_count"]
    diagnostics = dict(render_result.diagnostics or {})
    diagnostics["multi_piece_title_overlay_applied"] = True
    diagnostics["multi_piece_title_overlay_titles"] = [piece_titles[1]]
    render_result.diagnostics = diagnostics


def _overlay_centered_second_piece_title(pdf_path: Path, title: str) -> None:
    from pypdf import PdfReader, PdfWriter
    from pypdf._page import PageObject
    from pypdf.generic import DecodedStreamObject, DictionaryObject, NameObject

    reader = PdfReader(str(pdf_path))
    if len(reader.pages) != 1:
        return

    writer = PdfWriter(clone_from=reader)
    page = writer.pages[0]
    page_width = float(page.mediabox.width)
    page_height = float(page.mediabox.height)
    font_size = _multi_piece_title_font_size(title, page_width)
    estimated_title_width = len(title) * font_size * 0.59
    text_x = max(page_width * 0.08, (page_width - estimated_title_width) / 2)
    text_y = page_height * 0.461

    erase_x = 0.0
    erase_y = page_height * 0.440
    erase_width = page_width * 0.60
    erase_height = page_height * 0.085

    overlay_page = PageObject.create_blank_page(width=page_width, height=page_height)
    font_resource = DictionaryObject(
        {
            NameObject("/Type"): NameObject("/Font"),
            NameObject("/Subtype"): NameObject("/Type1"),
            NameObject("/BaseFont"): NameObject("/Times-Bold"),
        }
    )
    overlay_page[NameObject("/Resources")] = DictionaryObject(
        {
            NameObject("/Font"): DictionaryObject({NameObject("/F1"): font_resource}),
        }
    )
    content = (
        "q\n"
        "1 1 1 rg\n"
        f"{erase_x:.2f} {erase_y:.2f} {erase_width:.2f} {erase_height:.2f} re f\n"
        "BT\n"
        f"/F1 {font_size:.2f} Tf\n"
        "0 0 0 rg\n"
        f"{text_x:.2f} {text_y:.2f} Td\n"
        f"({_pdf_text_escape(title)}) Tj\n"
        "ET\n"
        "Q\n"
    ).encode("ascii", errors="ignore")
    stream = DecodedStreamObject()
    stream.set_data(content)
    overlay_page[NameObject("/Contents")] = stream

    page.merge_page(overlay_page)
    with pdf_path.open("wb") as output:
        writer.write(output)


def _multi_piece_title_font_size(title: str, page_width: float) -> float:
    title_length = max(1, len(title))
    max_width = page_width * 0.45
    return max(14.0, min(22.0, max_width / (title_length * 0.59)))


def _pdf_text_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def _authoritative_catalog_metadata_for_processing(
    *,
    piece: Piece,
    piece_metadata: dict[str, object],
    catalog_metadata: dict,
    result_data: dict[str, object],
) -> dict:
    metadata = dict(catalog_metadata)
    for key, value in {
        "title": piece.title,
        "composer": piece.composer,
        "primary_instrument": piece_metadata.get("primary_instrument")
        or result_data.get("primary_instrument"),
        "book_or_collection": piece_metadata.get("book_or_collection"),
        "source_page_start": piece_metadata.get("source_page_start")
        or result_data.get("source_page_start"),
        "source_page_end": piece_metadata.get("source_page_end")
        or result_data.get("source_page_end"),
        "contained_piece_titles": result_data.get("contained_piece_titles")
        or catalog_metadata.get("contained_piece_titles"),
        "multi_piece_page": result_data.get("multi_piece_page")
        or catalog_metadata.get("multi_piece_page"),
    }.items():
        if value not in (None, "", []):
            metadata[key] = value
    return {key: value for key, value in metadata.items() if value not in (None, "", [])}


def _merge_catalog_suggestions(
    existing: object,
    incoming: list[dict[str, object]],
) -> list[dict[str, object]]:
    suggestions: list[dict[str, object]] = []
    seen: set[str] = set()
    for source in (existing, incoming):
        if not isinstance(source, list):
            continue
        for suggestion in source:
            if not isinstance(suggestion, dict):
                continue
            key = repr(
                (
                    suggestion.get("source"),
                    suggestion.get("confidence"),
                    suggestion.get("fields"),
                )
            )
            if key in seen:
                continue
            seen.add(key)
            suggestions.append(suggestion)
    return suggestions


def _selected_omr_candidate_payload(
    *,
    candidate_id: str,
    label: str,
    raw_score_version_id: str,
    canonical_score_version_id: str,
    rendered_score_version_id: str,
    musicxml_result,
    musicxml_metadata: dict[str, object],
    processed_metadata: dict[str, object],
    render_result: RenderResult,
    warnings: list[str],
    selected: bool,
    profile: str | None = None,
) -> dict[str, object]:
    return {
        "candidate_id": candidate_id,
        "label": label,
        "profile": profile,
        "engine_name": musicxml_result.engine_name,
        "engine_version": musicxml_result.engine_version,
        "provenance": musicxml_result.provenance,
        "confidence": musicxml_result.confidence,
        "omr_quality_score": _numeric_metadata(musicxml_metadata, "omr_quality_score"),
        "processed_metadata": processed_metadata,
        "musicxml_metadata": musicxml_metadata,
        "renderer_name": render_result.renderer_name,
        "renderer_version": render_result.renderer_version,
        "renderer_provenance": render_result.provenance,
        "render_validation_status": render_result.validation_status,
        "render_validation_error": render_result.validation_error,
        "rendered_file_size_bytes": render_result.file_size_bytes,
        "rendered_page_count": render_result.page_count,
        "render_diagnostics": render_result.diagnostics,
        "raw_score_version_id": raw_score_version_id,
        "score_version_id": rendered_score_version_id,
        "canonical_score_version_id": canonical_score_version_id,
        "warnings": sorted(set(warnings)),
        "selected": selected,
    }


def _omr_candidate_payload_from_artifact(
    *,
    artifact: OmrCandidateArtifact,
    raw_score_version_id: str,
    canonical_score_version_id: str,
    rendered_score_version_id: str,
    selected: bool,
) -> dict[str, object]:
    return {
        "candidate_id": artifact.candidate_id,
        "label": artifact.label,
        "profile": artifact.profile,
        "engine_name": artifact.engine_name,
        "engine_version": artifact.engine_version,
        "provenance": artifact.provenance,
        "confidence": artifact.confidence,
        "omr_quality_score": artifact.quality_score,
        "processed_metadata": artifact.processed_metadata,
        "musicxml_metadata": artifact.musicxml_metadata,
        "renderer_name": artifact.render_result.renderer_name,
        "renderer_version": artifact.render_result.renderer_version,
        "renderer_provenance": artifact.render_result.provenance,
        "render_validation_status": artifact.render_result.validation_status,
        "render_validation_error": artifact.render_result.validation_error,
        "rendered_file_size_bytes": artifact.render_result.file_size_bytes,
        "rendered_page_count": artifact.render_result.page_count,
        "render_diagnostics": artifact.render_result.diagnostics,
        "raw_score_version_id": raw_score_version_id,
        "score_version_id": rendered_score_version_id,
        "canonical_score_version_id": canonical_score_version_id,
        "warnings": sorted(set(artifact.warnings)),
        "selected": selected,
    }


def _render_alternative_omr_candidate_artifacts(
    *,
    piece_dir: Path,
    raw_path: Path,
    selected_canonical_path: Path,
    selected_engine_name: str | None,
    title: str,
    composer: str | None,
    primary_instrument: str | None,
    contained_piece_titles: list[str] | None,
    multi_piece_page: bool,
    ocr_metadata: dict[str, object],
    processing_settings: dict[str, object],
    raw_page_count: int | None,
    attempts: object,
) -> list[OmrCandidateArtifact]:
    if not isinstance(attempts, list):
        return []

    output_dir = piece_dir / "candidate_options"
    output_dir.mkdir(parents=True, exist_ok=True)
    selected_resolved = selected_canonical_path.resolve()
    artifacts: list[OmrCandidateArtifact] = []
    seen_candidate_ids = {"selected_best"}
    seen_paths = {str(selected_resolved).lower()}
    selected_engine_key = _candidate_engine_key(selected_engine_name)

    for attempt in attempts:
        if not isinstance(attempt, dict):
            continue
        if attempt.get("skipped") or attempt.get("error"):
            continue
        candidate_path_text = attempt.get("candidate_path")
        if not isinstance(candidate_path_text, str) or not candidate_path_text.strip():
            continue
        source_path = Path(candidate_path_text)
        if not source_path.exists() or not source_path.is_file():
            continue
        resolved_source = str(source_path.resolve()).lower()
        if resolved_source in seen_paths:
            continue
        seen_paths.add(resolved_source)

        engine_name = _clean_candidate_text(attempt.get("engine")) or "omr"
        if selected_engine_key and _candidate_engine_key(engine_name) == selected_engine_key:
            continue
        profile = _clean_candidate_text(attempt.get("profile")) or "default"
        candidate_id = _unique_candidate_id(
            _safe_candidate_id(f"{engine_name}_{profile}"),
            seen_candidate_ids,
        )
        canonical_path = output_dir / f"{candidate_id}.musicxml"
        if source_path.suffix.lower() == ".mxl":
            source_for_normalization = source_path
        else:
            canonical_path.write_bytes(source_path.read_bytes())
            source_for_normalization = canonical_path

        spacing_enabled = engine_name.lower() == "audiveris"
        normalized_path, spacing_metadata = _normalize_musicxml_metadata_with_spacing(
            source_for_normalization,
            output_path=canonical_path,
            title=title,
            composer=composer,
            primary_instrument=primary_instrument,
            contained_piece_titles=contained_piece_titles,
            multi_piece_page=multi_piece_page,
            normalize_omr_spacing=spacing_enabled,
        )
        musicxml_metadata = _validate_musicxml(normalized_path)
        if spacing_metadata:
            musicxml_metadata.update(spacing_metadata)
        quality_score = _numeric_metadata(attempt, "quality_score")
        if quality_score is not None:
            musicxml_metadata["omr_quality_score"] = quality_score
        musicxml_metadata["omr_strategy"] = "candidate_bakeoff"
        musicxml_metadata["omr_candidate_engine"] = engine_name
        musicxml_metadata["omr_candidate_profile"] = profile

        processed_metadata = _merge_metadata(ocr_metadata, musicxml_metadata)
        if primary_instrument:
            processed_metadata["primary_instrument"] = primary_instrument

        rendered_path = output_dir / f"{candidate_id}_review.pdf"
        render_error: Exception | None = None
        try:
            render_result = MuseScoreRenderEngine().render(
                canonical_path=normalized_path,
                raw_pdf_path=raw_path,
                output_pdf_path=rendered_path,
                processing_settings=processing_settings,
            )
        except (OSError, ProcessingEngineError, subprocess.TimeoutExpired) as exc:
            render_error = exc
            render_result = _blocked_render_result(rendered_path, exc)
        _repair_multi_piece_review_pdf_titles(
            render_result,
            contained_piece_titles=contained_piece_titles,
            multi_piece_page=multi_piece_page,
        )
        _attach_spacing_normalization_diagnostics(render_result, musicxml_metadata)

        warnings = list(attempt.get("warnings") or [])
        warnings.extend(render_result.warnings)
        warnings.extend(
            _score_candidate_review_warnings(
                raw_pdf_path=raw_path,
                raw_page_count=raw_page_count,
                render_result=render_result,
                musicxml_provenance=str(
                    attempt.get("provenance") or f"{engine_name.lower()}_omr"
                ),
                contained_piece_titles=contained_piece_titles,
                multi_piece_page=multi_piece_page,
            )
        )
        if render_error is not None:
            warnings.append(str(render_error))

        artifacts.append(
            OmrCandidateArtifact(
                candidate_id=candidate_id,
                label=_omr_candidate_label(engine_name, profile),
                canonical_path=normalized_path,
                rendered_path=render_result.file_path,
                engine_name=engine_name,
                engine_version=_clean_candidate_text(attempt.get("engine_version")),
                provenance=str(attempt.get("provenance") or f"{engine_name.lower()}_omr"),
                confidence=_candidate_confidence(engine_name),
                quality_score=quality_score,
                musicxml_metadata=musicxml_metadata,
                processed_metadata=processed_metadata,
                render_result=render_result,
                warnings=warnings,
                profile=profile,
            )
        )

    return artifacts


def _numeric_metadata(metadata: dict, key: str) -> float | None:
    value = metadata.get(key)
    if isinstance(value, (int, float)):
        return float(value)
    return None


def _candidate_engine_key(engine_name: str | None) -> str | None:
    cleaned = _clean_candidate_text(engine_name)
    if cleaned is None:
        return None
    return cleaned.lower()


def _clean_candidate_text(value: object) -> str | None:
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None


def _safe_candidate_id(value: str) -> str:
    safe = "".join(char.lower() if char.isalnum() else "_" for char in value)
    safe = "_".join(part for part in safe.split("_") if part)
    return safe or "candidate"


def _unique_candidate_id(base_id: str, seen: set[str]) -> str:
    candidate_id = base_id
    suffix = 2
    while candidate_id in seen:
        candidate_id = f"{base_id}_{suffix}"
        suffix += 1
    seen.add(candidate_id)
    return candidate_id


def _omr_candidate_label(engine_name: str, profile: str | None) -> str:
    engine_label = {
        "audiveris": "Audiveris",
        "homr": "HOMR",
        "stub": "Stub",
    }.get(engine_name.lower(), engine_name)
    if profile and profile not in {"default", "experimental"}:
        return f"{engine_label} {profile.replace('_', ' ')}"
    if profile == "experimental":
        return f"{engine_label} experimental"
    return engine_label


def _candidate_confidence(engine_name: str) -> float:
    if engine_name.lower() == "audiveris":
        return 0.82
    if engine_name.lower() == "homr":
        return 0.72
    return 0.64
