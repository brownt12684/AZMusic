"""Durable processing settings and executable capability checks."""

from __future__ import annotations

import json
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any

from server.config import settings
from server.models.schemas import (
    ProcessingExecutableStatus,
    ProcessingMode,
    ProcessingSettingsResponse,
    ProcessingSettingsUpdate,
    ProcessingValidationResponse,
)


class ProcessingSettingsStore:
    """JSON-backed settings store for parent-managed processing configuration."""

    def __init__(self, settings_path: Path | None = None) -> None:
        self._settings_path = settings_path

    @property
    def path(self) -> Path:
        return self._settings_path or settings.storage_path / "processing_settings.json"

    def load(self) -> dict[str, Any]:
        defaults = self._defaults()
        if not self.path.exists():
            return defaults

        try:
            payload = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return defaults

        merged = {**defaults, **payload}
        if merged.get("processing_mode") not in {mode.value for mode in ProcessingMode}:
            merged["processing_mode"] = ProcessingMode.server_only.value
        if settings.production_mode:
            merged["production_mode"] = True
            merged["allow_stub_musicxml"] = False
        return merged

    def load_response(self) -> ProcessingSettingsResponse:
        payload = self._response_payload(self.load())
        return ProcessingSettingsResponse(**payload)

    def save(self, update: ProcessingSettingsUpdate) -> ProcessingSettingsResponse:
        payload = self.load()
        update_data = update.model_dump(exclude_unset=True)
        for key, value in update_data.items():
            if value is None:
                payload[key] = None
            elif isinstance(value, ProcessingMode):
                payload[key] = value.value
            elif key.endswith("_path") and isinstance(value, str):
                payload[key] = value.strip() or None
            elif key in {
                "local_llm_provider",
                "local_llm_model",
                "ocr_language",
                "cloud_provider",
                "cloud_model",
                "cloud_base_url",
                "cloud_api_key",
            } and isinstance(value, str):
                payload[key] = value.strip() or None
            else:
                payload[key] = value

        if settings.production_mode:
            payload["production_mode"] = True
            payload["allow_stub_musicxml"] = False

        payload["updated_at"] = _utc_now_iso()
        self._write(payload)
        return ProcessingSettingsResponse(**self._response_payload(payload))

    def record_last_error(self, error: str | None) -> None:
        payload = self.load()
        payload["last_processing_error"] = error
        payload["updated_at"] = _utc_now_iso()
        self._write(payload)

    def record_last_llm_error(self, error: str | None) -> None:
        payload = self.load()
        payload["last_llm_processing_error"] = error
        payload["updated_at"] = _utc_now_iso()
        self._write(payload)

    def record_last_cloud_error(self, error: str | None) -> None:
        payload = self.load()
        payload["last_cloud_processing_error"] = error
        payload["updated_at"] = _utc_now_iso()
        self._write(payload)

    def validate(
        self,
        update: ProcessingSettingsUpdate | None = None,
    ) -> ProcessingValidationResponse:
        payload = self.load()
        if update is not None:
            for key, value in update.model_dump(exclude_unset=True).items():
                if isinstance(value, ProcessingMode):
                    payload[key] = value.value
                else:
                    payload[key] = value

        audiveris = executable_status(
            name="Audiveris",
            configured_path=payload.get("audiveris_cli_path"),
            fallback_names=("audiveris",),
        )
        musescore = executable_status(
            name="MuseScore",
            configured_path=payload.get("musescore_cli_path"),
            fallback_names=("musescore", "mscore", "MuseScore4"),
        )
        ocr = executable_status(
            name="Tesseract OCR",
            configured_path=payload.get("ocr_cli_path"),
            fallback_names=("tesseract",),
        )
        warnings = []
        production_mode = bool(payload.get("production_mode") or settings.production_mode)
        if production_mode:
            if not audiveris.available:
                warnings.append(
                    "Production processing requires Audiveris before processed "
                    "candidates can be approved."
                )
            if not musescore.available:
                warnings.append(
                    "Production processing requires MuseScore before rendered "
                    "review PDFs can be approved."
                )
            if not ocr.available:
                warnings.append(
                    "Production processing requires Tesseract OCR for score "
                    "metadata and book preprocessing."
                )
        elif not audiveris.configured and payload.get("allow_stub_musicxml", True):
            warnings.append(
                "Audiveris is not configured; development imports will use stub MusicXML."
            )
        if not musescore.configured:
            warnings.append(
                "MuseScore is not configured; rendered review PDFs will fall back to the raw PDF."
            )
        if not ocr.available:
            warnings.append(
                "Tesseract OCR is not configured; scanned image metadata will fall back "
                "to filename and parent review."
            )
        if payload.get("cloud_enabled") and not payload.get("cloud_provider"):
            warnings.append("Cloud processing is enabled but no cloud provider is configured.")
        if payload.get("cloud_provider") and not payload.get("cloud_api_key"):
            warnings.append("Cloud provider is configured but no API key has been saved.")

        configured_executables_are_valid = True
        if audiveris.configured and not audiveris.available:
            configured_executables_are_valid = False
        if musescore.configured and not musescore.available:
            configured_executables_are_valid = False
        if ocr.configured and not ocr.available:
            configured_executables_are_valid = False
        if production_mode and (
            not audiveris.available or not musescore.available or not ocr.available
        ):
            configured_executables_are_valid = False

        return ProcessingValidationResponse(
            valid=configured_executables_are_valid,
            audiveris=audiveris,
            musescore=musescore,
            ocr=ocr,
            warnings=warnings,
        )

    def _defaults(self) -> dict[str, Any]:
        return {
            "audiveris_cli_path": settings.audiveris_cli_path,
            "musescore_cli_path": settings.musescore_cli_path,
            "ocr_cli_path": settings.ocr_cli_path,
            "ocr_language": settings.ocr_language or "eng",
            "processing_mode": settings.processing_mode
            if settings.processing_mode in {mode.value for mode in ProcessingMode}
            else ProcessingMode.server_only.value,
            "allow_stub_musicxml": settings.allow_stub_musicxml,
            "production_mode": settings.production_mode,
            "last_processing_error": None,
            "local_llm_provider": None,
            "local_llm_model": None,
            "last_llm_processing_error": None,
            "cloud_enabled": False,
            "cloud_provider": None,
            "cloud_model": None,
            "cloud_base_url": None,
            "cloud_api_key": None,
            "last_cloud_processing_error": None,
            "updated_at": _utc_now_iso(),
        }

    def _response_payload(self, payload: dict[str, Any]) -> dict[str, Any]:
        response_payload = dict(payload)
        response_payload["production_mode"] = bool(
            response_payload.get("production_mode") or settings.production_mode
        )
        response_payload["cloud_api_key_configured"] = bool(response_payload.get("cloud_api_key"))
        response_payload.pop("cloud_api_key", None)
        return response_payload

    def _write(self, payload: dict[str, Any]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp_path = self.path.with_suffix(".tmp")
        tmp_path.write_text(
            json.dumps(payload, indent=2, sort_keys=True),
            encoding="utf-8",
        )
        tmp_path.replace(self.path)


def executable_status(
    *,
    name: str,
    configured_path: str | None,
    fallback_names: tuple[str, ...],
) -> ProcessingExecutableStatus:
    configured = bool(configured_path)
    resolved_path = _resolve_executable(configured_path, fallback_names)
    status = ProcessingExecutableStatus(
        name=name,
        configured_path=configured_path,
        discovered_path=resolved_path,
        configured=configured,
        available=resolved_path is not None,
    )

    if configured and resolved_path is None:
        status.error = "Configured executable was not found."
        return status

    if resolved_path is None:
        return status

    version = _read_executable_version(resolved_path)
    if version.startswith("ERROR:"):
        status.error = version.removeprefix("ERROR:").strip()
    else:
        status.version = version or None
    return status


def _resolve_executable(
    configured_path: str | None,
    fallback_names: tuple[str, ...],
) -> str | None:
    if configured_path:
        path = Path(configured_path).expanduser()
        if path.exists():
            return str(path)
        discovered = shutil.which(configured_path)
        if discovered:
            return discovered
        return None

    for fallback_name in fallback_names:
        discovered = shutil.which(fallback_name)
        if discovered:
            return discovered
    return None


def _read_executable_version(executable_path: str) -> str:
    for version_arg in ("--version", "-version"):
        try:
            result = subprocess.run(
                [executable_path, version_arg],
                check=False,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=8,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            return f"ERROR: {exc}"

        output = (result.stdout or result.stderr).strip()
        if output:
            if "not a valid option" in output.lower():
                continue
            return output.splitlines()[0][:200]
        if result.returncode == 0:
            return ""

    return "ERROR: Executable did not return version information."


def _utc_now_iso() -> str:
    return datetime.utcnow().isoformat()
