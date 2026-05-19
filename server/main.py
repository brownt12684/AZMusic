"""AZMusic FastAPI server — LAN-only processing service for v1."""

from contextlib import asynccontextmanager

from fastapi import FastAPI

from server.database import engine
from server.routers import jobs, pieces, review, sync


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: initialize database tables, warm job scheduler
    from server.database import init_db  # noqa: PLC0414

    await init_db()
    yield
    # Shutdown: drain job queue, close connections
    await engine.dispose()


app = FastAPI(
    title="AZMusic Server",
    description="LAN-only processing server for AZMusic family music practice system.",
    version="0.1.0",
    lifespan=lifespan,
)

# Register routers
app.include_router(pieces.router, prefix="/api/v1/pieces", tags=["pieces"])
app.include_router(review.router, prefix="/api/v1/review", tags=["review"])
app.include_router(jobs.router, prefix="/api/v1/jobs", tags=["jobs"])
app.include_router(sync.router, prefix="/api/v1/sync", tags=["sync"])


@app.get("/health")
async def health():
    return {"status": "ok", "server": "azmusic", "version": "0.1.0"}
