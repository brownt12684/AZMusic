"""Router for Activity Feed, Practice Sessions, Events, and Goals."""

from datetime import datetime
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models.orm import (
    ActivityEvent,
    Event,
    Goal,
    PracticeSession,
    Profile,
)
from server.models.schemas import (
    ActivityEventResponse,
    ActivityEventCreate,
    EventResponse,
    EventCreate,
    GoalResponse,
    GoalCreate,
    PracticeSessionResponse,
    PracticeSessionCreate,
)

router = APIRouter()



@router.get("/feed", response_model=list[ActivityEventResponse])
async def get_activity_feed(
    student_id: str | None = None,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
):
    """Get the activity feed. If student_id is provided, filters for that student."""
    stmt = select(ActivityEvent).order_by(ActivityEvent.created_at.desc()).limit(limit)
    if student_id:
        # Include global events or events specifically targeting this student
        stmt = stmt.where(
            (ActivityEvent.target_profile_id == student_id) |
            (ActivityEvent.target_profile_id.is_(None))
        )
    
    result = await db.execute(stmt)
    events = result.scalars().all()

    return [
        ActivityEventResponse(
            id=e.id,
            event_type=e.event_type,
            profile_id=e.profile_id,
            target_profile_id=e.target_profile_id,
            piece_id=e.piece_id,
            recording_id=e.recording_id,
            content=e.content,
            created_at=e.created_at,
        )
        for e in events
    ]


@router.get("/students/{student_id}/sessions", response_model=list[PracticeSessionResponse])
async def get_practice_sessions(
    student_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Get practice sessions for a student."""
    stmt = (
        select(PracticeSession)
        .where(PracticeSession.student_profile_id == student_id)
        .order_by(PracticeSession.session_date.desc())
    )
    result = await db.execute(stmt)
    sessions = result.scalars().all()

    return [
        PracticeSessionResponse(
            id=s.id,
            student_profile_id=s.student_profile_id,
            piece_id=s.piece_id,
            duration_seconds=s.duration_seconds,
            session_date=s.session_date,
        )
        for s in sessions
    ]


@router.get("/events", response_model=list[EventResponse])
async def get_events(
    db: AsyncSession = Depends(get_db),
):
    """Get all events (global and student-specific)."""
    stmt = select(Event).order_by(Event.start_time.asc())
    result = await db.execute(stmt)
    events = result.scalars().all()

    return [
        EventResponse(
            id=e.id,
            title=e.title,
            description=e.description,
            start_time=e.start_time,
            end_time=e.end_time,
            student_profile_id=e.student_profile_id,
            teacher_profile_id=e.teacher_profile_id,
            created_at=e.created_at,
        )
        for e in events
    ]


@router.get("/students/{student_id}/goals", response_model=list[GoalResponse])
async def get_goals(
    student_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Get goals for a student."""
    stmt = (
        select(Goal)
        .where(Goal.student_profile_id == student_id)
        .order_by(Goal.created_at.desc())
    )
    result = await db.execute(stmt)
    goals = result.scalars().all()

    return [
        GoalResponse(
            id=g.id,
            title=g.title,
            description=g.description,
            student_profile_id=g.student_profile_id,
            piece_id=g.piece_id,
            due_date=g.due_date,
            is_completed=g.is_completed,
            created_at=g.created_at,
        )
        for g in goals
    ]


async def ensure_profile_exists(db: AsyncSession, profile_id: str, role: str = "student", name: str | None = None) -> Profile:
    stmt = select(Profile).where(Profile.id == profile_id)
    result = await db.execute(stmt)
    profile = result.scalar_one_or_none()
    if not profile:
        profile = Profile(
            id=profile_id,
            name=name or f"Student ({profile_id})",
            role=role,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        db.add(profile)
        await db.flush()
    return profile


@router.post("/students/{student_id}/goals", response_model=GoalResponse)
async def create_goal(
    student_id: str,
    body: GoalCreate,
    db: AsyncSession = Depends(get_db),
):
    """Create a goal for a student."""
    await ensure_profile_exists(db, student_id)
    
    g = Goal(
        id=str(uuid.uuid4()),
        title=body.title,
        description=body.description,
        student_profile_id=student_id,
        piece_id=body.piece_id,
        due_date=body.due_date,
        is_completed=False,
        created_at=datetime.utcnow(),
    )
    db.add(g)
    await db.commit()
    
    # Log an ActivityEvent for this
    content = f"Assigned a new goal: {body.title}"
    evt = ActivityEvent(
        id=str(uuid.uuid4()),
        event_type="system_alert",
        target_profile_id=student_id,
        piece_id=body.piece_id,
        content=content,
        created_at=datetime.utcnow(),
    )
    db.add(evt)
    await db.commit()
    
    return GoalResponse(
        id=g.id,
        title=g.title,
        description=g.description,
        student_profile_id=g.student_profile_id,
        piece_id=g.piece_id,
        due_date=g.due_date,
        is_completed=g.is_completed,
        created_at=g.created_at,
    )


@router.patch("/goals/{goal_id}/toggle", response_model=GoalResponse)
async def toggle_goal(
    goal_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Toggle the completion status of a goal."""
    g = await db.get(Goal, goal_id)
    if not g:
        raise HTTPException(status_code=404, detail="Goal not found")
    
    g.is_completed = not g.is_completed
    await db.commit()
    
    # Log an activity event
    status = "completed" if g.is_completed else "re-opened"
    content = f"Goal status updated: {g.title} is now {status}"
    evt = ActivityEvent(
        id=str(uuid.uuid4()),
        event_type="system_alert",
        target_profile_id=g.student_profile_id,
        piece_id=g.piece_id,
        content=content,
        created_at=datetime.utcnow(),
    )
    db.add(evt)
    await db.commit()
    
    return GoalResponse(
        id=g.id,
        title=g.title,
        description=g.description,
        student_profile_id=g.student_profile_id,
        piece_id=g.piece_id,
        due_date=g.due_date,
        is_completed=g.is_completed,
        created_at=g.created_at,
    )


@router.post("/events", response_model=EventResponse)
async def create_event(
    body: EventCreate,
    db: AsyncSession = Depends(get_db),
):
    """Create a calendar event."""
    if body.student_profile_id:
        await ensure_profile_exists(db, body.student_profile_id)
    if body.teacher_profile_id:
        await ensure_profile_exists(db, body.teacher_profile_id, role="teacher")
        
    e = Event(
        id=str(uuid.uuid4()),
        title=body.title,
        description=body.description,
        start_time=body.start_time,
        end_time=body.end_time,
        student_profile_id=body.student_profile_id,
        teacher_profile_id=body.teacher_profile_id,
        created_at=datetime.utcnow(),
    )
    db.add(e)
    await db.commit()
    
    return EventResponse(
        id=e.id,
        title=e.title,
        description=e.description,
        start_time=e.start_time,
        end_time=e.end_time,
        student_profile_id=e.student_profile_id,
        teacher_profile_id=e.teacher_profile_id,
        created_at=e.created_at,
    )


@router.post("/students/{student_id}/sessions", response_model=PracticeSessionResponse)
async def create_practice_session(
    student_id: str,
    body: PracticeSessionCreate,
    db: AsyncSession = Depends(get_db),
):
    """Log a student practice session."""
    await ensure_profile_exists(db, student_id)
    
    s = PracticeSession(
        id=str(uuid.uuid4()),
        student_profile_id=student_id,
        piece_id=body.piece_id,
        duration_seconds=body.duration_seconds,
        session_date=body.session_date,
    )
    db.add(s)
    
    minutes = body.duration_seconds // 60
    content = f"Practiced for {minutes} minutes"
    evt = ActivityEvent(
        id=str(uuid.uuid4()),
        event_type="submission",
        target_profile_id=student_id,
        piece_id=body.piece_id,
        content=content,
        created_at=body.session_date,
    )
    db.add(evt)
    await db.commit()
    
    return PracticeSessionResponse(
        id=s.id,
        student_profile_id=s.student_profile_id,
        piece_id=s.piece_id,
        duration_seconds=s.duration_seconds,
        session_date=s.session_date,
    )


@router.post("/feed", response_model=ActivityEventResponse)
async def create_activity_event(
    body: ActivityEventCreate,
    db: AsyncSession = Depends(get_db),
):
    """Create a custom activity event."""
    if body.profile_id:
        await ensure_profile_exists(db, body.profile_id)
    if body.target_profile_id:
        await ensure_profile_exists(db, body.target_profile_id)
        
    e = ActivityEvent(
        id=str(uuid.uuid4()),
        event_type=body.event_type,
        profile_id=body.profile_id,
        target_profile_id=body.target_profile_id,
        piece_id=body.piece_id,
        recording_id=body.recording_id,
        content=body.content,
        created_at=datetime.utcnow(),
    )
    db.add(e)
    await db.commit()
    
    return ActivityEventResponse(
        id=e.id,
        event_type=e.event_type,
        profile_id=e.profile_id,
        target_profile_id=e.target_profile_id,
        piece_id=e.piece_id,
        recording_id=e.recording_id,
        content=e.content,
        created_at=e.created_at,
    )

