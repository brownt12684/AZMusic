"""Durable processing settings and executable capability checks."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

from server.config import settings
from server.models.schemas import (
    OmrStrategy,
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
        if merged.get("omr_strategy") not in {strategy.value for strategy in OmrStrategy}:
            merged["omr_strategy"] = OmrStrategy.audiveris_quality_sweep.value
        _apply_discovered_tool_paths(merged)
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
                "local_llm_base_url",
                "ocr_language",
                "ocr_effort",
                "cloud_provider",
                "cloud_model",
                "cloud_base_url",
                "cloud_api_key",
                "cloud_auth_mode",
            } and isinstance(value, str):
                payload[key] = value.strip() or None
            elif isinstance(value, OmrStrategy):
                payload[key] = value.value
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
                elif isinstance(value, OmrStrategy):
                    payload[key] = value.value
                else:
                    payload[key] = value

        audiveris = executable_status(
            name="Audiveris",
            configured_path=payload.get("audiveris_cli_path"),
            fallback_names=("audiveris",),
        )
        homr = homr_status(payload)
        legato = legato_status(payload)
        musescore = executable_status(
            name="MuseScore Studio",
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
                    "Production processing requires MuseScore Studio before rendered "
                    "review PDFs can be approved."
                )
            if not ocr.available:
                warnings.append(
                    "Production processing requires Tesseract OCR for score "
                    "metadata and book preprocessing."
                )
        elif not audiveris.available and payload.get("allow_stub_musicxml", True):
            warnings.append(
                "Audiveris is not configured; development imports will use stub MusicXML."
            )
        if not musescore.available:
            warnings.append(
                "MuseScore Studio is not configured; rendered review PDFs will "
                "fall back to the raw PDF."
            )
        if not ocr.available:
            warnings.append(
                "Tesseract OCR is not configured; scanned image metadata will fall back "
                "to filename and parent review."
            )
        elif not _tesseract_language_available(
            ocr.discovered_path,
            str(payload.get("ocr_language") or "eng"),
        ):
            warnings.append(
                f"Tesseract OCR is available, but language data for "
                f"{payload.get('ocr_language') or 'eng'} was not reported."
            )
        omr_strategy = str(payload.get("omr_strategy") or "")
        if (
            omr_strategy
            in {
                OmrStrategy.homr_experimental.value,
                OmrStrategy.omr_bakeoff.value,
                OmrStrategy.experimental_engine_bakeoff.value,
            }
            and not homr.available
        ):
            warnings.append(
                "HOMR is selected for experimental OMR, but the HOMR CLI is not available."
            )
        if (
            omr_strategy
            in {
                OmrStrategy.legato_experimental.value,
                OmrStrategy.omr_bakeoff.value,
                OmrStrategy.experimental_engine_bakeoff.value,
            }
            and not legato.available
        ):
            warnings.append(
                "LEGATO is selected for experimental OMR, but the LEGATO runner or "
                "model is not available."
            )
        cloud_provider = payload.get("cloud_provider") or "gemini"
        cloud_auth_mode = payload.get("cloud_auth_mode") or "oauth"
        if payload.get("cloud_enabled") and not cloud_provider:
            warnings.append("Cloud processing is enabled but no cloud provider is configured.")
        if (
            payload.get("cloud_enabled")
            and cloud_provider != "gemini"
            and cloud_auth_mode != "oauth"
            and not payload.get("cloud_api_key")
        ):
            warnings.append("Cloud provider is configured but no API key has been saved.")

        configured_executables_are_valid = True
        if audiveris.configured and not audiveris.available:
            configured_executables_are_valid = False
        if homr.configured and not homr.available:
            configured_executables_are_valid = False
        if omr_strategy == OmrStrategy.homr_experimental.value and not homr.available:
            configured_executables_are_valid = False
        if legato.configured and not legato.available:
            configured_executables_are_valid = False
        if (
            omr_strategy == OmrStrategy.legato_experimental.value
            and not legato.available
        ):
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
            homr=homr,
            legato=legato,
            musescore=musescore,
            ocr=ocr,
            warnings=warnings,
        )

    def _defaults(self) -> dict[str, Any]:
        return {
            "audiveris_cli_path": settings.audiveris_cli_path
            or discover_executable_path(("audiveris",)),
            "homr_cli_path": settings.homr_cli_path or discover_executable_path(("homr",)),
            "legato_cli_path": settings.legato_cli_path
            or discover_executable_path(("legato-runner", "legato")),
            "legato_model_path": settings.legato_model_path,
            "musescore_cli_path": settings.musescore_cli_path
            or discover_executable_path(("musescore", "mscore", "MuseScore4")),
            "musescore_style_path": None,
            "ocr_cli_path": settings.ocr_cli_path or discover_executable_path(("tesseract",)),
            "ocr_language": settings.ocr_language or "eng",
            "ocr_effort": "balanced",
            "omr_strategy": OmrStrategy.audiveris_quality_sweep.value,
            "max_concurrent_jobs": _clamp_int(settings.max_concurrent_jobs, 1, 4, 2),
            "processing_mode": settings.processing_mode
            if settings.processing_mode in {mode.value for mode in ProcessingMode}
            else ProcessingMode.server_only.value,
            "allow_stub_musicxml": settings.allow_stub_musicxml,
            "production_mode": settings.production_mode,
            "last_processing_error": None,
            "local_llm_provider": None,
            "local_llm_model": None,
            "local_llm_base_url": None,
            "last_llm_processing_error": None,
            "cloud_enabled": False,
            "cloud_provider": "gemini",
            "cloud_model": settings.gemini_default_model,
            "cloud_base_url": None,
            "cloud_api_key": None,
            "cloud_auth_mode": "oauth",
            "last_cloud_processing_error": None,
            "updated_at": _utc_now_iso(),
        }

    def _response_payload(self, payload: dict[str, Any]) -> dict[str, Any]:
        response_payload = dict(payload)
        response_payload["max_concurrent_jobs"] = _clamp_int(
            response_payload.get("max_concurrent_jobs"),
            1,
            4,
            2,
        )
        response_payload["production_mode"] = bool(
            response_payload.get("production_mode") or settings.production_mode
        )
        response_payload["cloud_api_key_configured"] = bool(response_payload.get("cloud_api_key"))
        response_payload.pop("cloud_api_key", None)
        if not response_payload.get("cloud_provider"):
            response_payload["cloud_provider"] = "gemini"
        if not response_payload.get("cloud_model"):
            response_payload["cloud_model"] = settings.gemini_default_model
        response_payload["cloud_auth_mode"] = response_payload.get("cloud_auth_mode") or "oauth"
        if response_payload["cloud_provider"] == "gemini":
            from server.services.gemini_oauth import GeminiOAuthManager

            gemini_status = GeminiOAuthManager().status()
            response_payload["cloud_oauth_connected"] = gemini_status.connected
            response_payload["cloud_oauth_account"] = gemini_status.account_email
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
        status.error = (
            _musescore_missing_error()
            if _is_musescore_lookup(
                name,
                fallback_names,
            )
            else "Configured executable was not found."
        )
        return status

    if resolved_path is None:
        if _is_musescore_lookup(name, fallback_names):
            status.error = _musescore_missing_error()
        return status

    version = _read_executable_version(resolved_path)
    if version.startswith("ERROR:"):
        status.error = version.removeprefix("ERROR:").strip()
    else:
        status.version = version or None
    return status


def homr_status(payload: dict[str, Any]) -> ProcessingExecutableStatus:
    """Return HOMR CLI status without requiring a formal --version response."""

    configured_path = payload.get("homr_cli_path")
    configured = bool(configured_path)
    resolved_path = _resolve_executable(
        configured_path if isinstance(configured_path, str) else None,
        ("homr",),
    )
    status = ProcessingExecutableStatus(
        name="HOMR",
        configured_path=configured_path if isinstance(configured_path, str) else None,
        discovered_path=resolved_path,
        configured=configured,
        available=resolved_path is not None,
    )
    if configured and resolved_path is None:
        status.error = "Configured HOMR executable was not found."
        return status
    if resolved_path is None:
        status.error = (
            "HOMR CLI was not found. Install experimental HOMR support in the "
            "server tool environment before selecting HOMR OMR modes."
        )
        return status

    version = _read_homr_version(resolved_path)
    if version.startswith("ERROR:"):
        status.error = version.removeprefix("ERROR:").strip()
    else:
        status.version = version or "HOMR CLI available"
    return status


def legato_status(payload: dict[str, Any]) -> ProcessingExecutableStatus:
    """Return LEGATO runner status, including the required model artifact."""

    configured_path = payload.get("legato_cli_path")
    configured = bool(configured_path)
    resolved_path = _resolve_executable(
        configured_path if isinstance(configured_path, str) else None,
        ("legato-runner", "legato"),
    )
    model_path = payload.get("legato_model_path")
    model_configured = isinstance(model_path, str) and bool(model_path.strip())
    model_ready = model_configured and _legato_model_reference_is_available(str(model_path))
    model_needs_huggingface_auth = (
        model_configured
        and str(model_path).strip().lower() == "guangyangmusic/legato"
        and not _huggingface_token_available()
    )
    status = ProcessingExecutableStatus(
        name="LEGATO",
        configured_path=configured_path if isinstance(configured_path, str) else None,
        discovered_path=resolved_path,
        configured=configured or model_configured,
        available=resolved_path is not None and bool(model_ready),
    )
    if configured and resolved_path is None:
        status.error = "Configured LEGATO runner was not found."
        return status
    if resolved_path is None:
        status.error = (
            "LEGATO runner was not found. Install an experimental LEGATO runner "
            "before selecting LEGATO OMR modes."
        )
        return status
    if not model_configured:
        status.error = "LEGATO runner is available, but no model path is configured."
        return status
    if not model_ready:
        status.error = (
            "Configured LEGATO model was not found. Use a local model path or a "
            "Hugging Face model id such as guangyangmusic/legato."
        )
        return status
    if model_needs_huggingface_auth:
        status.available = False
        status.error = (
            "The official guangyangmusic/legato model requires Hugging Face login "
            "and approved model access, or configure a local LEGATO model directory."
        )
        return status

    version = _read_legato_version(resolved_path)
    if version.startswith("ERROR:"):
        status.error = version.removeprefix("ERROR:").strip()
        status.available = False
    else:
        status.version = version or "LEGATO runner available"
    return status


def discover_executable_path(fallback_names: tuple[str, ...]) -> str | None:
    for fallback_name in fallback_names:
        discovered = shutil.which(fallback_name)
        if discovered:
            return discovered

    for candidate in _common_executable_candidates(fallback_names):
        if candidate.exists():
            return str(candidate)

    return None


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

    return discover_executable_path(fallback_names)


def _apply_discovered_tool_paths(payload: dict[str, Any]) -> None:
    for key, fallback_names in (
        ("audiveris_cli_path", ("audiveris",)),
        ("homr_cli_path", ("homr",)),
        ("legato_cli_path", ("legato-runner", "legato")),
        ("musescore_cli_path", ("musescore", "mscore", "MuseScore4")),
        ("ocr_cli_path", ("tesseract",)),
    ):
        configured_path = payload.get(key)
        if configured_path and _resolve_configured_executable(configured_path):
            continue
        discovered = discover_executable_path(fallback_names)
        if discovered:
            payload[key] = discovered


def _resolve_configured_executable(configured_path: object) -> str | None:
    if not isinstance(configured_path, str) or not configured_path.strip():
        return None
    path = Path(configured_path).expanduser()
    if path.exists():
        return str(path)
    return shutil.which(configured_path)


def _common_executable_candidates(fallback_names: tuple[str, ...]) -> list[Path]:
    program_files = _windows_program_directories()
    normalized_names = {name.lower() for name in fallback_names}
    candidates: list[Path] = []

    if "audiveris" in normalized_names:
        for root in program_files:
            candidates.extend(
                [
                    root / "Audiveris" / "Audiveris.exe",
                    root / "Audiveris" / "bin" / "Audiveris.bat",
                    root / "Audiveris" / "bin" / "audiveris.bat",
                ]
            )
            candidates.extend(sorted(root.glob("Audiveris*/Audiveris.exe")))

    if normalized_names.intersection({"musescore", "mscore", "musescore4"}):
        for root in program_files:
            candidates.extend(
                [
                    root / "MuseScore 4" / "bin" / "MuseScore4.exe",
                    root / "MuseScore 3" / "bin" / "MuseScore3.exe",
                    root / "MuseScore" / "bin" / "MuseScore.exe",
                    root / "Programs" / "MuseScore 4" / "bin" / "MuseScore4.exe",
                ]
            )
            candidates.extend(sorted(root.glob("MuseScore*/bin/MuseScore*.exe")))

    if "tesseract" in normalized_names:
        for root in program_files:
            candidates.extend(
                [
                    root / "Tesseract-OCR" / "tesseract.exe",
                    root / "Tesseract OCR" / "tesseract.exe",
                ]
            )

    if "homr" in normalized_names:
        local_app_data = os.environ.get("LOCALAPPDATA")
        if local_app_data:
            candidates.extend(
                [
                    Path(local_app_data)
                    / "AZMusic"
                    / "Server"
                    / "tools"
                    / "homr"
                    / ".venv"
                    / "Scripts"
                    / "homr.exe",
                    Path(local_app_data)
                    / "AZMusic"
                    / "Server"
                    / "tools"
                    / "homr"
                    / "venv"
                    / "Scripts"
                    / "homr.exe",
                ]
            )

    if normalized_names.intersection({"legato-runner", "legato"}):
        local_app_data = os.environ.get("LOCALAPPDATA")
        if local_app_data:
            candidates.extend(
                [
                    Path(local_app_data)
                    / "AZMusic"
                    / "Server"
                    / "tools"
                    / "legato"
                    / ".venv"
                    / "Scripts"
                    / "legato-runner.exe",
                    Path(local_app_data)
                    / "AZMusic"
                    / "Server"
                    / "tools"
                    / "legato"
                    / "legato-runner.py",
                    Path(local_app_data)
                    / "AZMusic"
                    / "Server"
                    / "tools"
                    / "legato"
                    / "legato-runner.cmd",
                    Path(local_app_data)
                    / "AZMusic"
                    / "Server"
                    / "tools"
                    / "legato"
                    / "venv"
                    / "Scripts"
                    / "legato-runner.exe",
                ]
            )
        candidates.append(
            Path(__file__).resolve().parents[1] / "tools" / "legato_runner.py"
        )

    seen: set[Path] = set()
    unique_candidates: list[Path] = []
    for candidate in candidates:
        normalized = candidate
        if normalized in seen:
            continue
        seen.add(normalized)
        unique_candidates.append(candidate)
    return unique_candidates


def _is_musescore_lookup(name: str, fallback_names: tuple[str, ...]) -> bool:
    normalized_names = {fallback_name.lower() for fallback_name in fallback_names}
    return name.lower().startswith("musescore") or bool(
        normalized_names.intersection({"musescore", "mscore", "musescore4"})
    )


def _musescore_missing_error() -> str:
    muse_hub_path = _discover_muse_hub_path()
    if muse_hub_path:
        return (
            "Muse Hub was detected, but MuseScore Studio was not found. "
            "Install MuseScore Studio inside Muse Hub or from musescore.org, "
            "then rerun server setup or refresh processing settings."
        )
    return "MuseScore Studio executable was not found."


def _discover_muse_hub_path() -> Path | None:
    candidates: list[Path] = []
    local_app_data = os.environ.get("LOCALAPPDATA")
    if local_app_data:
        candidates.append(Path(local_app_data) / "Programs" / "Muse Hub" / "Muse Hub.exe")
    for root in _windows_program_directories():
        candidates.extend(
            [
                root / "Muse Hub" / "Muse Hub.exe",
                root / "MuseHub" / "Muse Hub.exe",
            ]
        )
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None


def _windows_program_directories() -> list[Path]:
    roots = [
        os.environ.get("ProgramFiles"),
        os.environ.get("ProgramFiles(x86)"),
        os.environ.get("LOCALAPPDATA"),
    ]
    paths: list[Path] = []
    for root in roots:
        if not root:
            continue
        path = Path(root)
        if path not in paths:
            paths.append(path)
    return paths


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


def _read_homr_version(executable_path: str) -> str:
    for command in (
        [executable_path, "--version"],
        [executable_path, "--help"],
    ):
        try:
            result = subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=12,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            return f"ERROR: {exc}"
        output = (result.stdout or result.stderr).strip()
        if result.returncode != 0:
            return f"ERROR: {output or f'LEGATO runner exited with {result.returncode}.'}"
        if output:
            lowered_output = output.lower()
            if command[-1] == "--version" and (
                "unrecognized arguments" in lowered_output or "not a valid option" in lowered_output
            ):
                continue
            first_line = output.splitlines()[0][:200]
            return first_line if command[-1] == "--version" else "HOMR CLI available"
        if result.returncode == 0:
            return "HOMR CLI available"
    return "ERROR: HOMR CLI did not return help or version information."


def _read_legato_version(executable_path: str) -> str:
    for command in (
        [*_script_command_prefix(executable_path), "--version"],
        [*_script_command_prefix(executable_path), "--help"],
    ):
        try:
            result = subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=12,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            return f"ERROR: {exc}"
        output = (result.stdout or result.stderr).strip()
        if output:
            lowered_output = output.lower()
            if command[-1] == "--version" and (
                "unrecognized arguments" in lowered_output
                or "not a valid option" in lowered_output
            ):
                continue
            first_line = output.splitlines()[0][:200]
            return first_line if command[-1] == "--version" else "LEGATO runner available"
        if result.returncode == 0:
            return "LEGATO runner available"
    return "ERROR: LEGATO runner did not return help or version information."


def _script_command_prefix(executable_path: str) -> list[str]:
    path = Path(executable_path).expanduser()
    if not path.is_absolute():
        path = path.resolve()
    if path.suffix.lower() == ".py":
        return [sys.executable, str(path)]
    return [str(path)]


def _legato_model_reference_is_available(model_reference: str) -> bool:
    raw = model_reference.strip()
    if not raw:
        return False
    if Path(raw).expanduser().exists():
        return True
    return _looks_like_huggingface_model_id(raw)


def _looks_like_huggingface_model_id(model_reference: str) -> bool:
    if "\\" in model_reference or ":" in model_reference:
        return False
    parts = model_reference.split("/")
    if len(parts) != 2 or not all(parts):
        return False
    allowed = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
    return all(set(part) <= allowed for part in parts)


def _huggingface_token_available() -> bool:
    for key in ("HF_TOKEN", "HUGGING_FACE_HUB_TOKEN", "HUGGINGFACE_HUB_TOKEN"):
        if os.environ.get(key):
            return True
    token_path = Path.home() / ".cache" / "huggingface" / "token"
    try:
        return token_path.exists() and bool(token_path.read_text(encoding="utf-8").strip())
    except OSError:
        return False


def _tesseract_language_available(executable_path: str | None, language: str) -> bool:
    if not executable_path:
        return False
    try:
        result = subprocess.run(
            [executable_path, "--list-langs"],
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    if result.returncode != 0:
        return False
    languages = {
        line.strip().lower()
        for line in (result.stdout or "").splitlines()
        if line.strip() and "list of available languages" not in line.lower()
    }
    return language.strip().lower() in languages


def _utc_now_iso() -> str:
    return datetime.utcnow().isoformat()


def _clamp_int(value: Any, minimum: int, maximum: int, default: int) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return default
    return max(minimum, min(maximum, parsed))
