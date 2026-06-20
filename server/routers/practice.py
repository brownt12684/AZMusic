"""Router for student practice recordings and teacher/parent requests."""

from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
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
        student_profile_id="",  # Set by auth layer or client
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
