"""Router for processing settings, capabilities, and experimental workers."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models.schemas import (
    DeviceWorkerRegistrationRequest,
    DeviceWorkerResponse,
    ProcessingCapabilityResponse,
    ProcessingSettingsResponse,
    ProcessingSettingsUpdate,
    ProcessingValidationResponse,
)
from server.services.cloud_llm import cloud_llm_status
from server.services.device_workers import DeviceWorkerRegistry
from server.services.job_summary import build_job_summary
from server.services.local_llm import local_llm_status
from server.services.processing_settings import ProcessingSettingsStore

router = APIRouter()
_settings_store = ProcessingSettingsStore()
_device_workers = DeviceWorkerRegistry()


@router.get("/settings", response_model=ProcessingSettingsResponse)
async def get_processing_settings():
    """Return durable server-side processing settings."""
    return _settings_store.load_response()


@router.patch("/settings", response_model=ProcessingSettingsResponse)
async def update_processing_settings(body: ProcessingSettingsUpdate):
    """Update durable server-side processing settings."""
    return _settings_store.save(body)


@router.post("/settings/validate", response_model=ProcessingValidationResponse)
async def validate_processing_settings(body: ProcessingSettingsUpdate):
    """Validate supplied processing settings without saving them."""
    return _settings_store.validate(body)


@router.get("/capabilities", response_model=ProcessingCapabilityResponse)
async def get_processing_capabilities(db: AsyncSession = Depends(get_db)):
    """Return configured engines, discovered executables, and worker registrations."""
    settings = _settings_store.load_response()
    settings_payload = _settings_store.load()
    validation = _settings_store.validate()
    workers = _device_workers.list_workers()
    return ProcessingCapabilityResponse(
        server_online=True,
        settings=settings,
        audiveris=validation.audiveris,
        musescore=validation.musescore,
        ocr=validation.ocr,
        local_llm=local_llm_status(settings_payload),
        cloud_llm=cloud_llm_status(settings_payload),
        device_workers_enabled=(
            settings.processing_mode.value
            in {"server_plus_device_workers", "server_plus_device_and_cloud_workers"}
        ),
        cloud_workers_enabled=(
            settings.processing_mode.value
            in {"server_plus_cloud_workers", "server_plus_device_and_cloud_workers"}
        ),
        device_workers=workers,
        job_summary=await build_job_summary(db),
        warnings=validation.warnings,
    )


@router.post("/device-workers/register", response_model=DeviceWorkerResponse)
async def register_device_worker(body: DeviceWorkerRegistrationRequest):
    """Register or refresh an experimental device processing worker."""
    return _device_workers.register(body)


@router.get("/device-workers", response_model=list[DeviceWorkerResponse])
async def list_device_workers():
    """List registered experimental processing workers."""
    return _device_workers.list_workers()
