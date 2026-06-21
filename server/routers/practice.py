"""Router for student practice recordings and teacher/parent requests."""

from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.config import settings
from server.database import get_db
from server.models.orm import (
    Piece,
    PracticeRecording,
    Profile,
    RecordingRequest,
)
from server.models.schemas import (
    PracticeAlertItem,
    PracticeAlertsResponse,
    PracticeRecordingResponse,
    RecordingRequestCreate,
    RecordingRequestResponse,
)

router = APIRouter()


@router.post("/recordings/upload", response_model=PracticeRecordingResponse)
async def upload_practice_recording(
    piece_id: str = File(...),
    student_profile_id: str = File(...),
    audio_file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
):
    """Upload a student practice recording (audio file)."""
    # Validate piece exists
    result = await db.execute(select(Piece).where(Piece.id == piece_id))
    piece = result.scalar_one_or_none()
    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")

    # Save file to storage/recordings/
    recordings_dir = settings.storage_path / "recordings"
    recordings_dir.mkdir(parents=True, exist_ok=True)

    suffix = Path(audio_file.filename or "recording.mp3").suffix.lower()
    safe_piece_id = "".join(
        c if c.isalnum() or c in {"-", "_"} else "_" for c in piece_id
    )
    filename = f"{safe_piece_id}_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}{suffix}"
    file_path = recordings_dir / filename

    content = await audio_file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Recording file was empty.")

    file_path.write_bytes(content)

    # Create recording record
    now = datetime.utcnow()
    recording = PracticeRecording(
        student_profile_id=student_profile_id,
        piece_id=piece_id,
        local_file_path=str(file_path),
        submitted_at=now,
    )
    db.add(recording)
    await db.commit()
    await db.refresh(recording)

    return PracticeRecordingResponse(
        id=recording.id,
        student_profile_id=recording.student_profile_id,
        piece_id=recording.piece_id,
        local_file_path=recording.local_file_path,
        submitted_at=recording.submitted_at,
    )


@router.post("/requests/create", response_model=RecordingRequestResponse)
async def create_recording_request(
    body: RecordingRequestCreate,
    db: AsyncSession = Depends(get_db),
):
    """Create a teacher/parent recording request or note for a student."""
    # Validate student profile exists
    result = await db.execute(
        select(Profile).where(Profile.id == body.student_profile_id)
    )
    student = result.scalar_one_or_none()
    if not student:
        raise HTTPException(status_code=404, detail="Student profile not found")

    # Validate piece if provided
    if body.piece_id:
        result = await db.execute(select(Piece).where(Piece.id == body.piece_id))
        piece = result.scalar_one_or_none()
        if not piece:
            raise HTTPException(status_code=404, detail="Piece not found")

    now = datetime.utcnow()
    request = RecordingRequest(
        teacher_profile_id="",  # Set by auth layer or client
        student_profile_id=body.student_profile_id,
        piece_id=body.piece_id,
        message_notes=body.message_notes,
        is_read=False,
        created_at=now,
    )
    db.add(request)
    await db.commit()
    await db.refresh(request)

    return RecordingRequestResponse(
        id=request.id,
        teacher_profile_id=request.teacher_profile_id,
        student_profile_id=request.student_profile_id,
        piece_id=request.piece_id,
        message_notes=request.message_notes,
        is_read=request.is_read,
        created_at=request.created_at,
    )


@router.get(
    "/student/{student_id}/alerts", response_model=PracticeAlertsResponse
)
async def get_student_alerts(
    student_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Get unread recording requests and notes for a student profile."""
    # Validate student profile exists
    result = await db.execute(
        select(Profile).where(Profile.id == student_id)
    )
    student = result.scalar_one_or_none()
    if not student:
        raise HTTPException(status_code=404, detail="Student profile not found")

    # Fetch unread requests with teacher name and piece title
    stmt = (
        select(
            RecordingRequest,
            Profile.name.label("teacher_name"),
            Piece.title.label("piece_title"),
        )
        .join(Profile, RecordingRequest.teacher_profile_id == Profile.id)
        .outerjoin(Piece, RecordingRequest.piece_id == Piece.id)
        .where(
            RecordingRequest.student_profile_id == student_id,
            RecordingRequest.is_read == False,  # noqa: E712
        )
        .order_by(RecordingRequest.created_at.desc())
    )
    result = await db.execute(stmt)
    rows = result.all()

    alerts = []
    for req, teacher_name, piece_title in rows:
        alerts.append(PracticeAlertItem(
            id=req.id,
            teacher_profile_id=req.teacher_profile_id,
            teacher_name=teacher_name or "Teacher",
            student_profile_id=req.student_profile_id,
            piece_id=req.piece_id,
            piece_title=piece_title,
            message_notes=req.message_notes,
            is_read=req.is_read,
            created_at=req.created_at,
        ))

    return PracticeAlertsResponse(pending_requests=alerts)


@router.post("/requests/{request_id}/read")
async def mark_request_read(
    request_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Mark a recording request as read."""
    result = await db.execute(
        select(RecordingRequest).where(RecordingRequest.id == request_id)
    )
    req = result.scalar_one_or_none()
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")

    req.is_read = True
    req.updated_at = datetime.utcnow()
    await db.commit()
    return {"id": req.id, "is_read": True}


@router.get("/student/{student_id}/recordings", response_model=list[PracticeRecordingResponse])
async def get_student_recordings(
    student_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Get all practice recordings for a student with piece titles."""
    result = await db.execute(select(PracticeRecording).order_by(PracticeRecording.submitted_at.desc()))
    recordings = result.scalars().all()

    # Build a lookup of piece_id -> title
    piece_ids = {r.piece_id for r in recordings}
    if piece_ids:
        pieces_result = await db.execute(
            select(Piece).where(Piece.id.in_(piece_ids))
        )
        pieces = {p.id: p.title for p in pieces_result.scalars().all()}
    else:
        pieces = {}

    return [
        PracticeRecordingResponse(
            id=r.id,
            student_profile_id=r.student_profile_id,
            piece_id=r.piece_id,
            local_file_path=r.local_file_path,
            submitted_at=r.submitted_at,
        )
        for r in recordings
    ]

@router.get("/recordings/{recording_id}/file")
async def get_practice_recording_file(
    recording_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Serve a student practice recording file for download/streaming."""
    result = await db.execute(
        select(PracticeRecording).where(PracticeRecording.id == recording_id)
    )
    recording = result.scalar_one_or_none()
    if not recording:
        raise HTTPException(status_code=404, detail="Recording not found")

    local_path = Path(recording.local_file_path or "")
    if not local_path.exists():
        raise HTTPException(
            status_code=404,
            detail=f"Local recording file not found: {local_path}",
        )

    # Determine content type from suffix
    suffix = local_path.suffix.lower()
    if suffix == ".mp4":
        content_type = "video/mp4"
    elif suffix == ".m4a":
        content_type = "audio/mp4"
    elif suffix == ".mp3":
        content_type = "audio/mpeg"
    else:
        content_type = "application/octet-stream"

    return FileResponse(
        path=str(local_path),
        media_type=content_type,
        filename=local_path.name,
    )
