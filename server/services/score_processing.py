"""Deterministic score import and candidate generation for the first review slice."""

from __future__ import annotations

import shutil
import subprocess
import uuid
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

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


@dataclass(slots=True)
class ImportedPieceArtifacts:
    piece: Piece
    raw_score_version: ScoreVersion
    canonical_score_version: ScoreVersion
    rendered_score_version: ScoreVersion
    review_item: ReviewItem
    job: BackgroundJob


class ScoreProcessingService:
    """Create deterministic review candidates for imported PDFs."""

    async def import_pdf(
        self,
        db: AsyncSession,
        *,
        title: str,
        composer: str | None,
        file_name: str,
        file_bytes: bytes,
    ) -> ImportedPieceArtifacts:
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

        try:
            canonical_path = piece_dir / "candidate.musicxml"
            canonical_path.write_text(
                _build_stub_musicxml(title=title, composer=composer),
                encoding="utf-8",
            )
            canonical_score_version = ScoreVersion(
                id=str(uuid.uuid4()),
                piece_id=piece_id,
                version_type=ScoreVersionType.reconstructed_candidate,
                file_path=str(canonical_path),
                is_default=False,
                created_at=now,
            )
            db.add(canonical_score_version)
            await db.flush()

            rendered_path = piece_dir / "candidate_review.pdf"
            _render_candidate_pdf(
                canonical_path=canonical_path,
                raw_pdf_path=raw_path,
                output_pdf_path=rendered_path,
            )
            rendered_score_version = ScoreVersion(
                id=str(uuid.uuid4()),
                piece_id=piece_id,
                version_type=ScoreVersionType.reconstructed_candidate,
                file_path=str(rendered_path),
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
                    "summary": (
                        "Deterministic PDF-first candidate prepared for parent review."
                    ),
                    "confidence": 0.64,
                    "provenance": "fixture_stub_musicxml",
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
            }
            job.updated_at = datetime.utcnow()

            await db.commit()
            await db.refresh(piece)
            await db.refresh(raw_score_version)
            await db.refresh(canonical_score_version)
            await db.refresh(rendered_score_version)
            await db.refresh(review_item)
            await db.refresh(job)
        except Exception as exc:
            job.status = JobStatus.failed
            job.error_message = str(exc)
            job.updated_at = datetime.utcnow()
            piece.status = PieceStatus.imported
            piece.updated_at = datetime.utcnow()
            await db.commit()
            raise

        return ImportedPieceArtifacts(
            piece=piece,
            raw_score_version=raw_score_version,
            canonical_score_version=canonical_score_version,
            rendered_score_version=rendered_score_version,
            review_item=review_item,
            job=job,
        )


def _render_candidate_pdf(
    *,
    canonical_path: Path,
    raw_pdf_path: Path,
    output_pdf_path: Path,
) -> None:
    """Render with MuseScore when configured, otherwise copy the source PDF."""

    cli_path = settings.musescore_cli_path
    if cli_path:
        cli = Path(cli_path)
        if cli.exists():
            try:
                subprocess.run(
                    [str(cli), str(canonical_path), "-o", str(output_pdf_path)],
                    check=True,
                    capture_output=True,
                    text=True,
                )
                if output_pdf_path.exists():
                    return
            except Exception:
                pass

    shutil.copy2(raw_pdf_path, output_pdf_path)


def _build_stub_musicxml(*, title: str, composer: str | None) -> str:
    composer_xml = f"<creator type=\"composer\">{_escape_xml(composer)}</creator>" if composer else ""
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE score-partwise PUBLIC
  "-//Recordare//DTD MusicXML 4.0 Partwise//EN"
  "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="4.0">
  <work>
    <work-title>{_escape_xml(title)}</work-title>
  </work>
  <identification>
    {composer_xml}
    <encoding>
      <software>AZMusic deterministic stub</software>
      <encoding-date>{datetime.utcnow().date().isoformat()}</encoding-date>
    </encoding>
  </identification>
  <part-list>
    <score-part id="P1">
      <part-name>Violin</part-name>
    </score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
        <key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <direction placement="above">
        <direction-type>
          <words>Review candidate generated by AZMusic</words>
        </direction-type>
      </direction>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
      <note>
        <pitch><step>D</step><octave>4</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
      <note>
        <pitch><step>E</step><octave>4</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
      <note>
        <pitch><step>F</step><octave>4</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
    </measure>
  </part>
</score-partwise>
"""


def _escape_xml(value: str | None) -> str:
    if not value:
        return ""
    return (
        value.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&apos;")
    )
