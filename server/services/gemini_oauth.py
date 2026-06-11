"""Google Gemini OAuth credential management for parent-triggered review."""

from __future__ import annotations

import json
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

from server.config import settings
from server.models.schemas import GeminiOAuthStartResponse, GeminiOAuthStatusResponse

GEMINI_OAUTH_SCOPES = ("https://www.googleapis.com/auth/generative-language.retriever",)


class GeminiOAuthError(RuntimeError):
    """Raised when Gemini OAuth cannot be started or completed."""


@dataclass(frozen=True)
class GeminiCredentialsBundle:
    credentials: Any
    model: str


class GeminiOAuthManager:
    """Small file-backed OAuth manager for the AZMusic server package."""

    def __init__(self, storage_path: Path | None = None) -> None:
        self._storage_path = storage_path

    @property
    def storage_path(self) -> Path:
        return self._storage_path or settings.storage_path / "gemini_oauth"

    @property
    def token_path(self) -> Path:
        return self.storage_path / "token.json"

    @property
    def state_path(self) -> Path:
        return self.storage_path / "state.json"

    @property
    def client_secret_path(self) -> Path:
        configured = settings.gemini_oauth_client_secret_path
        if configured:
            return Path(configured).expanduser().resolve()
        return (settings.storage_path / "gemini_oauth_client_secret.json").resolve()

    def status(self) -> GeminiOAuthStatusResponse:
        error = self._configuration_error()
        connected = self.token_path.exists()
        available = False
        updated_at = self._token_updated_at()
        if error is None and connected:
            try:
                credentials = self.load_credentials(refresh=True).credentials
                available = bool(credentials and credentials.valid)
            except Exception as exc:  # noqa: BLE001
                error = str(exc)

        return GeminiOAuthStatusResponse(
            configured=error is None or connected,
            connected=connected,
            available=available,
            model=settings.gemini_default_model,
            error=error,
            scopes=list(GEMINI_OAUTH_SCOPES),
            updated_at=updated_at,
        )

    def start(self, redirect_base_url: str) -> GeminiOAuthStartResponse:
        error = self._configuration_error()
        if error is not None:
            raise GeminiOAuthError(error)
        flow = self._new_flow()
        redirect_uri = self._redirect_uri(redirect_base_url)
        flow.redirect_uri = redirect_uri
        state = secrets.token_urlsafe(32)
        authorization_url, _state = flow.authorization_url(
            access_type="offline",
            include_granted_scopes="true",
            prompt="consent select_account",
            state=state,
        )
        expires_at = datetime.utcnow() + timedelta(minutes=15)
        self._write_json(
            self.state_path,
            {
                "state": state,
                "redirect_uri": redirect_uri,
                "expires_at": expires_at.isoformat(),
            },
        )
        return GeminiOAuthStartResponse(
            authorization_url=authorization_url,
            state=state,
            redirect_uri=redirect_uri,
            expires_at=expires_at,
        )

    def finish(self, *, state: str, authorization_response: str) -> None:
        error = self._configuration_error()
        if error is not None:
            raise GeminiOAuthError(error)
        state_payload = self._read_json(self.state_path)
        expected_state = str(state_payload.get("state") or "")
        expires_at = _parse_datetime(state_payload.get("expires_at"))
        if not expected_state or not secrets.compare_digest(expected_state, state):
            raise GeminiOAuthError("Gemini OAuth state did not match this server session.")
        if expires_at is None or expires_at < datetime.utcnow():
            raise GeminiOAuthError("Gemini OAuth state expired. Start Google sign-in again.")

        flow = self._new_flow()
        flow.redirect_uri = str(state_payload.get("redirect_uri") or "")
        flow.fetch_token(authorization_response=authorization_response)
        credentials = flow.credentials
        self.storage_path.mkdir(parents=True, exist_ok=True)
        self.token_path.write_text(credentials.to_json(), encoding="utf-8")
        self._write_json(
            self.token_path.with_suffix(".metadata.json"),
            {"updated_at": datetime.utcnow().isoformat()},
        )
        self._delete_if_exists(self.state_path)

    def disconnect(self) -> None:
        self._delete_if_exists(self.token_path)
        self._delete_if_exists(self.token_path.with_suffix(".metadata.json"))
        self._delete_if_exists(self.state_path)

    def install_client_secret(self, *, file_name: str, content: bytes) -> GeminiOAuthStatusResponse:
        """Install a Google OAuth client JSON file supplied by the paired parent."""
        suffix = Path(file_name or "").suffix.lower()
        if suffix != ".json":
            raise GeminiOAuthError(
                "Choose the Google OAuth client JSON file downloaded from Google Cloud."
            )
        if not content:
            raise GeminiOAuthError("The uploaded Google OAuth client JSON file was empty.")
        if len(content) > 256 * 1024:
            raise GeminiOAuthError("The Google OAuth client JSON file is unexpectedly large.")

        try:
            payload = json.loads(content.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise GeminiOAuthError("The selected file is not valid JSON.") from exc
        if not isinstance(payload, dict):
            raise GeminiOAuthError(
                "The selected JSON file is not a Google OAuth client configuration."
            )

        client_kind, client_config = self._google_client_config(payload)
        missing_fields = [
            field
            for field in ("client_id", "auth_uri", "token_uri")
            if not str(client_config.get(field) or "").strip()
        ]
        if missing_fields:
            missing = ", ".join(missing_fields)
            raise GeminiOAuthError(
                f"The Google OAuth {client_kind} client JSON is missing required fields: {missing}."
            )

        self.client_secret_path.parent.mkdir(parents=True, exist_ok=True)
        self._write_json(self.client_secret_path, payload)
        # Tokens and pending states are tied to a specific OAuth client. Replacing
        # the client credential must force a fresh Google sign-in.
        self.disconnect()
        return self.status()

    def load_credentials(self, *, refresh: bool = True) -> GeminiCredentialsBundle:
        self._ensure_google_auth_packages()
        from google.auth.transport.requests import Request
        from google.oauth2.credentials import Credentials

        if not self.token_path.exists():
            raise GeminiOAuthError("Gemini is not connected. Sign in with Google first.")
        credentials = Credentials.from_authorized_user_file(
            str(self.token_path),
            scopes=list(GEMINI_OAUTH_SCOPES),
        )
        if refresh and credentials.expired and credentials.refresh_token:
            credentials.refresh(Request())
            self.token_path.write_text(credentials.to_json(), encoding="utf-8")
            self._write_json(
                self.token_path.with_suffix(".metadata.json"),
                {"updated_at": datetime.utcnow().isoformat()},
            )
        if not credentials.valid:
            raise GeminiOAuthError("Gemini OAuth credentials are not valid. Reconnect Google.")
        return GeminiCredentialsBundle(
            credentials=credentials,
            model=settings.gemini_default_model,
        )

    def _configuration_error(self) -> str | None:
        try:
            self._ensure_google_auth_packages()
        except GeminiOAuthError as exc:
            return str(exc)
        if not self.client_secret_path.exists():
            return (
                "Gemini OAuth client secret is not installed. Add the AZMusic "
                f"Google OAuth client JSON at {self.client_secret_path} or set "
                "GEMINI_OAUTH_CLIENT_SECRET_PATH."
            )
        return None

    def _google_client_config(self, payload: dict[str, Any]) -> tuple[str, dict[str, Any]]:
        for key in ("web", "installed"):
            value = payload.get(key)
            if isinstance(value, dict):
                return key, value
        raise GeminiOAuthError(
            "The selected JSON file is not a Google OAuth client secret. "
            "Download the OAuth client JSON from Google Cloud and try again."
        )

    def _new_flow(self) -> Any:
        self._ensure_google_auth_packages()
        from google_auth_oauthlib.flow import Flow

        return Flow.from_client_secrets_file(
            str(self.client_secret_path),
            scopes=list(GEMINI_OAUTH_SCOPES),
        )

    def _redirect_uri(self, redirect_base_url: str) -> str:
        configured = settings.gemini_oauth_redirect_base_url.strip()
        base_url = (configured or redirect_base_url).rstrip("/")
        return f"{base_url}/api/v1/processing/gemini/oauth/callback"

    def _token_updated_at(self) -> datetime | None:
        metadata = self._read_json(self.token_path.with_suffix(".metadata.json"))
        return _parse_datetime(metadata.get("updated_at"))

    def _ensure_google_auth_packages(self) -> None:
        try:
            import google.auth  # noqa: F401
            import google_auth_oauthlib.flow  # noqa: F401
        except Exception as exc:  # noqa: BLE001
            raise GeminiOAuthError(
                "Gemini OAuth packages are not installed. Install "
                "google-auth-oauthlib and google-auth."
            ) from exc

    def _read_json(self, path: Path) -> dict[str, Any]:
        if not path.exists():
            return {}
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return {}
        return payload if isinstance(payload, dict) else {}

    def _write_json(self, path: Path, payload: dict[str, Any]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp_path = path.with_suffix(".tmp")
        tmp_path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
        tmp_path.replace(path)

    def _delete_if_exists(self, path: Path) -> None:
        try:
            path.unlink()
        except FileNotFoundError:
            return


def _parse_datetime(value: object) -> datetime | None:
    if not isinstance(value, str) or not value.strip():
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None
