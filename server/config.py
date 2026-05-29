"""Server configuration loaded from environment with stable repo-relative defaults."""

from pathlib import Path

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

SERVER_DIR = Path(__file__).resolve().parent
DEFAULT_DATABASE_PATH = (SERVER_DIR / "azmusic_server.db").resolve()
DEFAULT_STORAGE_PATH = (SERVER_DIR / "storage").resolve()
SQLITE_URL_PREFIXES = ("sqlite+aiosqlite:///", "sqlite:///")


def _sqlite_url_for(path: Path, prefix: str = "sqlite+aiosqlite:///") -> str:
    return f"{prefix}{path.resolve().as_posix()}"


def _resolve_server_path(path: Path) -> Path:
    if path.is_absolute():
        return path.resolve()

    return (SERVER_DIR / path).resolve()


def _normalize_sqlite_url(database_url: str) -> str:
    for prefix in SQLITE_URL_PREFIXES:
        if not database_url.startswith(prefix):
            continue

        path_text = database_url.removeprefix(prefix)
        if path_text == ":memory:":
            return database_url

        return _sqlite_url_for(_resolve_server_path(Path(path_text)), prefix=prefix)

    return database_url


class Settings(BaseSettings):
    """AZMusic server settings."""

    model_config = SettingsConfigDict(
        env_file=SERVER_DIR / ".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    app_name: str = "AZMusic"
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = False
    production_mode: bool = False

    # Database
    database_url: str = Field(default_factory=lambda: _sqlite_url_for(DEFAULT_DATABASE_PATH))

    # File storage
    storage_path: Path = DEFAULT_STORAGE_PATH

    # LAN auth / device pairing
    lan_auth_token: str = ""
    require_device_auth: bool = False
    public_server_url: str = ""

    # AI / provider settings
    ai_enabled: bool = True
    max_concurrent_jobs: int = 2
    audiveris_cli_path: str | None = None
    musescore_cli_path: str | None = None
    ocr_cli_path: str | None = None
    ocr_language: str = "eng"
    processing_mode: str = "server_only"
    allow_stub_musicxml: bool = True
    job_dispatcher_enabled: bool = True
    job_dispatcher_poll_interval_seconds: float = 2.0
    job_dispatcher_stale_after_seconds: int = 600
    job_dispatcher_max_retries: int = 2

    @model_validator(mode="after")
    def normalize_paths(self) -> "Settings":
        self.database_url = _normalize_sqlite_url(self.database_url)
        self.storage_path = _resolve_server_path(self.storage_path)
        return self


settings = Settings()
