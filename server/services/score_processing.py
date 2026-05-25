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
)
from server.services.ocr_metadata import OcrMetadataExtractor
from server.services.piece_state import PieceStateService
from server.services.processing_engines import (
    MuseScoreRenderEngine,
    MusicXmlEngine,
    ProcessingEngineError,
)
from server.services.processing_settings import ProcessingSettingsStore, executable_status

__all__ = [
    "BookPageFact",
    "BookPreprocessingResult",
    "BookPreprocessor",
    "BookSplitProposal",
    "ScoreProcessingService",
]


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
            render_result = MuseScoreRenderEngine().render(
                canonical_path=musicxml_result.file_path,
                raw_pdf_path=raw_path,
                output_pdf_path=rendered_path,
                processing_settings=processing_settings,
            )
            warnings.extend(render_result.warnings)
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
                    "warnings": warnings,
                    "raw_score_version_id": raw_score_version.id,
                    "score_version_id": rendered_score_version.id,
                    "canonical_score_version_id": canonical_score_version.id,
                },
                created_at=now,
            )
            db.add(review_item)

            piece.status = PieceStatus.review_pending
            piece.updated_at = datetime.utcnow()
            job.status = JobStatus.succeeded
            job.progress = 100.0
            job.result_data = {
                "review_item_id": review_item.id,
                "raw_score_version_id": raw_score_version.id,
                "rendered_score_version_id": rendered_score_version.id,
                "canonical_score_version_id": canonical_score_version.id,
                "engine_name": musicxml_result.engine_name,
                "engine_version": musicxml_result.engine_version,
                "processed_metadata": processed_metadata,
                "ocr_metadata": ocr_metadata,
                "ocr_engine": ocr_result.engine_name,
                "ocr_confidence": ocr_result.confidence,
                "catalog_suggestions": ocr_result.catalog_suggestions,
                "renderer_name": render_result.renderer_name,
                "renderer_version": render_result.renderer_version,
                "warnings": warnings,
            }
            job.updated_at = datetime.utcnow()
            processing_settings_store.record_last_error(None)

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
        _ensure_production_processing_ready(processing_settings)
        piece_metadata = PieceStateService().metadata_for_piece(piece)
        catalog_metadata = piece_metadata.get("catalog_metadata") or {}
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

        canonical_path = piece_dir / "candidate.musicxml"
        job.progress = 35.0
        job.updated_at = datetime.utcnow()
        await db.commit()
        musicxml_result = await asyncio.to_thread(
            partial(
                MusicXmlEngine().generate,
                raw_pdf_path=raw_path,
                output_path=canonical_path,
                title=piece.title,
                composer=piece.composer,
                primary_instrument=primary_instrument,
                contained_piece_titles=contained_piece_titles,
                multi_piece_page=multi_piece_page,
                processing_settings=processing_settings,
            )
        )
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
        render_result = await asyncio.to_thread(
            partial(
                MuseScoreRenderEngine().render,
                canonical_path=musicxml_result.file_path,
                raw_pdf_path=raw_path,
                output_pdf_path=rendered_path,
                processing_settings=processing_settings,
            )
        )
        warnings.extend(render_result.warnings)

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
                "ocr_metadata": ocr_metadata,
                "ocr_engine": ocr_result.engine_name,
                "ocr_confidence": ocr_result.confidence,
                "catalog_suggestions": ocr_result.catalog_suggestions,
                "renderer_name": render_result.renderer_name,
                "renderer_version": render_result.renderer_version,
                "renderer_provenance": render_result.provenance,
                "warnings": warnings,
                "raw_score_version_id": raw_score_version.id,
                "score_version_id": rendered_score_version.id,
                "canonical_score_version_id": canonical_score_version.id,
                "source_review_item_id": result_data.get("source_review_item_id"),
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
        job.status = JobStatus.succeeded
        job.progress = 100.0
        job.error_message = None
        job.result_data = {
            **result_data,
            "raw_score_version_id": raw_score_version.id,
            "candidate_review_item_id": review_item.id,
            "rendered_score_version_id": rendered_score_version.id,
            "canonical_score_version_id": canonical_score_version.id,
            "engine_name": musicxml_result.engine_name,
            "engine_version": musicxml_result.engine_version,
            "processed_metadata": processed_metadata,
            "ocr_metadata": ocr_metadata,
            "ocr_engine": ocr_result.engine_name,
            "ocr_confidence": ocr_result.confidence,
            "catalog_suggestions": ocr_result.catalog_suggestions,
            "renderer_name": render_result.renderer_name,
            "renderer_version": render_result.renderer_version,
            "warnings": warnings,
            "contained_piece_titles": result_data.get("contained_piece_titles")
            or catalog_metadata.get("contained_piece_titles"),
            "multi_piece_page": result_data.get("multi_piece_page")
            or catalog_metadata.get("multi_piece_page"),
            "processing_stage": "candidate_review_needed",
        }
        job.updated_at = datetime.utcnow()
        processing_settings_store.record_last_error(None)

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
        ("MuseScore", "musescore_cli_path", ("musescore", "mscore", "MuseScore4")),
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
