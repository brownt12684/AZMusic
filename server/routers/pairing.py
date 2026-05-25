"""Router for pairing family devices to the LAN server."""

from io import BytesIO
from urllib.parse import quote

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import Response

from server.models.schemas import (
    PairingClaimRequest,
    PairingClaimResponse,
    PairingCodeResponse,
)
from server.services.pairing import PairingService

router = APIRouter()
_pairing_service = PairingService()


@router.get("/code", response_model=PairingCodeResponse)
async def create_pairing_code(
    request: Request,
    purpose: str = "student_device",
    profile_id: str | None = None,
    profile_name: str | None = None,
    role: str | None = "student",
):
    """Create a short-lived pairing code and QR payload for a family device."""
    server_url = _server_url_from_request(request)
    qr_url = str(request.url_for("get_pairing_qr_png"))
    placeholder = _pairing_service.create_code(
        server_url=server_url,
        qr_png_url=qr_url,
        purpose=purpose,
        profile_id=profile_id,
        profile_name=profile_name,
        role=role,
    )
    qr_png_url = f"{qr_url}?code={quote(placeholder.pairing_code)}"
    return placeholder.model_copy(update={"qr_png_url": qr_png_url})


@router.get("/code.png", name="get_pairing_qr_png")
async def get_pairing_qr_png(code: str):
    """Return a PNG QR code for a previously issued pairing code."""
    pairing_uri = _pairing_service.pairing_uri_for_code(code)
    if pairing_uri is None:
        raise HTTPException(status_code=404, detail="Pairing code not found or expired.")

    try:
        import qrcode
    except ImportError as exc:
        raise HTTPException(
            status_code=503,
            detail="QR generation dependency is not installed on the server.",
        ) from exc

    image = qrcode.make(pairing_uri)
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    return Response(content=buffer.getvalue(), media_type="image/png")


@router.post("/claim", response_model=PairingClaimResponse)
async def claim_pairing_code(body: PairingClaimRequest):
    """Claim a pairing code and return the device token to store locally."""
    result = _pairing_service.claim_code(
        pairing_code=body.pairing_code,
        device_id=body.device_id,
        device_name=body.device_name,
        platform=body.platform,
    )
    if result is None:
        raise HTTPException(status_code=404, detail="Pairing code not found or expired.")
    return result


def _server_url_from_request(request: Request) -> str:
    return str(request.base_url).rstrip("/")
