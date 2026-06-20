"""AZMusic FastAPI server — LAN-only processing service for v1."""

from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI

from server.config import settings
from server.database import engine
from server.jobs.dispatcher import JobDispatcher
from server.routers import (
    annotations,
    cloud,
    debug,
    jobs,
    media,
    notes,
    pairing,
    pieces,
    practice,
    processing,
    review,
    setup,
    sync,
    toc,
)
from server.services.auth import require_paired_device


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: initialize database tables, warm job scheduler
    from server.database import init_db  # noqa: PLC0414

    await init_db()
    dispatcher: JobDispatcher | None = None
    if settings.job_dispatcher_enabled:
        dispatcher = JobDispatcher()
        await dispatcher.start()
    yield
    # Shutdown: drain job queue, close connections
    if dispatcher:
        await dispatcher.stop()
    await engine.dispose()


app = FastAPI(
    title="AZMusic Server",
    description="LAN-only processing server for AZMusic family music practice system.",
    version="0.2.0",
    lifespan=lifespan,
)

# Register routers
_protected_dependencies = [Depends(require_paired_device)]
app.include_router(
    pieces.router,
    prefix="/api/v1/pieces",
    tags=["pieces"],
    dependencies=_protected_dependencies,
)
app.include_router(
    review.router,
    prefix="/api/v1/review",
    tags=["review"],
    dependencies=_protected_dependencies,
)
app.include_router(
    jobs.router,
    prefix="/api/v1/jobs",
    tags=["jobs"],
    dependencies=_protected_dependencies,
)
app.include_router(
    sync.router,
    prefix="/api/v1/sync",
    tags=["sync"],
    dependencies=_protected_dependencies,
)
app.include_router(
    processing.router,
    prefix="/api/v1/processing",
    tags=["processing"],
    dependencies=_protected_dependencies,
)
app.include_router(
    debug.router,
    prefix="/api/v1/debug",
    tags=["debug"],
    dependencies=_protected_dependencies,
)
app.include_router(
    cloud.router,
    prefix="/api/v1/cloud",
    tags=["cloud"],
    dependencies=_protected_dependencies,
)
app.include_router(
    notes.router,
    prefix="/api/v1/notes",
    tags=["notes"],
    dependencies=_protected_dependencies,
)
app.include_router(
    annotations.router,
    prefix="/api/v1/annotations",
    tags=["annotations"],
    dependencies=_protected_dependencies,
)
app.include_router(
    media.router,
    prefix="/api/v1/media",
    tags=["media"],
    dependencies=_protected_dependencies,
)
app.include_router(
    practice.router,
    prefix="/api/v1/practice",
    tags=["practice"],
    dependencies=_protected_dependencies,
)
app.include_router(
    toc.router,
    prefix="/api/v1",
    tags=["toc"],
    dependencies=_protected_dependencies,
)
app.include_router(pairing.router, prefix="/api/v1/pairing", tags=["pairing"])
app.include_router(setup.router, tags=["setup"])


@app.get("/health")
async def health():
    return {"status": "ok", "server": "azmusic", "version": "0.2.0"}
