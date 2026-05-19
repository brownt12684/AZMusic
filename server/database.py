"""SQLite database initialization using SQLAlchemy async engine + aiosqlite."""

from sqlalchemy import event
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from server.config import settings
from server.models.orm import Base

engine = create_async_engine(
    settings.database_url,
    echo=settings.debug,
)

# Enable WAL mode and foreign keys for SQLite.
# Async SQLAlchemy engines need listeners attached to the underlying sync engine.
@event.listens_for(engine.sync_engine, "connect")
def _set_sqlite_pragma(dbapi_connection, connection_record):
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA journal_mode=WAL;")
    cursor.execute("PRAGMA foreign_keys=ON;")
    cursor.close()


async_session = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def init_db():
    """Create all tables defined in models."""
    # Import all models so they register with Base.metadata
    import server.models  # noqa: F401, PLC0414

    settings.storage_path.mkdir(parents=True, exist_ok=True)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def get_db():
    """Dependency that yields an async database session."""
    async with async_session() as session:
        try:
            yield session
        finally:
            await session.close()
