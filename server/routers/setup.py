"""Server-hosted setup pages for family device pairing."""

from html import escape
from urllib.parse import quote

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse, RedirectResponse

from server.config import settings
from server.services.gemini_oauth import GeminiOAuthError, GeminiOAuthManager
from server.services.pairing import PairingService
from server.services.server_urls import reachable_server_urls

router = APIRouter()
_pairing_service = PairingService()
_gemini_oauth = GeminiOAuthManager()


@router.get("/setup", response_class=HTMLResponse)
async def setup_page(request: Request):
    """Display the server-side QR code that family devices scan to pair."""
    request_url = str(request.base_url).rstrip("/")
    server_urls = reachable_server_urls(request)
    server_url = server_urls[0]
    qr_url = str(request.url_for("get_pairing_qr_png"))
    pairing_code = _pairing_service.create_code(
        server_url=server_url,
        alternate_server_urls=server_urls[1:],
        qr_png_url=qr_url,
        purpose="parent_setup",
        profile_id="parent-main",
        profile_name="Parent",
        role="parent",
    )
    qr_png_url = f"{qr_url}?code={quote(pairing_code.pairing_code)}"
    return HTMLResponse(
        _setup_html(
            server_name=settings.app_name,
            server_url=server_url,
            alternate_server_urls=server_urls[1:],
            request_url=request_url,
            pairing_code=pairing_code.pairing_code,
            pairing_uri=pairing_code.pairing_uri,
            qr_png_url=qr_png_url,
            expires_at=pairing_code.expires_at.isoformat(),
        )
    )


@router.get("/setup/gemini")
async def start_gemini_setup(request: Request):
    """Start server-side Google sign-in for Gemini vision review."""
    try:
        start = _gemini_oauth.start(str(request.base_url).rstrip("/"))
    except GeminiOAuthError as exc:
        return HTMLResponse(_gemini_error_html(str(exc)), status_code=409)
    return RedirectResponse(start.authorization_url)


@router.get("/api/v1/processing/gemini/oauth/callback", response_class=HTMLResponse)
async def gemini_oauth_callback(request: Request, state: str = ""):
    """Complete Google OAuth after the browser returns to the server."""
    authorization_response = str(request.url)
    try:
        _gemini_oauth.finish(
            state=state,
            authorization_response=authorization_response,
        )
    except GeminiOAuthError as exc:
        return HTMLResponse(_gemini_error_html(str(exc)), status_code=409)
    return HTMLResponse(_gemini_success_html())


def _setup_html(
    *,
    server_name: str,
    server_url: str,
    alternate_server_urls: list[str],
    request_url: str,
    pairing_code: str,
    pairing_uri: str,
    qr_png_url: str,
    expires_at: str,
) -> str:
    opened_from_note = ""
    if request_url != server_url:
        opened_from_note = (
            f"<p><strong>Opened from:</strong> {escape(request_url)}</p>"
            "<p>This QR uses the detected network address so phones and tablets "
            "can reach the server.</p>"
        )

    alternate_urls_html = ""
    if alternate_server_urls:
        alternate_urls_html = (
            '<div class="alternates"><strong>Alternate URLs if pairing times out:</strong><ul>'
            + "".join(f"<li><code>{escape(url)}</code></li>" for url in alternate_server_urls)
            + "</ul></div>"
        )

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{escape(server_name)} Setup</title>
  <style>
    body {{
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      background: radial-gradient(circle at top left, #d9f4e8, #f7efe3 42%, #f8f6f0);
      color: #1b1b16;
      font-family: "Segoe UI", sans-serif;
    }}
    main {{
      width: min(920px, calc(100vw - 32px));
      display: grid;
      grid-template-columns: minmax(260px, 360px) 1fr;
      gap: 28px;
      padding: 28px;
      background: rgba(255, 255, 255, 0.88);
      border: 1px solid rgba(27, 27, 22, 0.10);
      border-radius: 28px;
      box-shadow: 0 24px 80px rgba(32, 28, 20, 0.14);
    }}
    .qr {{
      display: grid;
      place-items: center;
      padding: 20px;
      background: #ffffff;
      border-radius: 24px;
      border: 1px solid rgba(27, 27, 22, 0.12);
    }}
    img {{
      width: min(100%, 320px);
      aspect-ratio: 1;
    }}
    h1 {{
      margin: 0 0 12px;
      font-size: clamp(32px, 5vw, 56px);
      line-height: 0.95;
      letter-spacing: -0.05em;
    }}
    p {{
      color: #5d594f;
      line-height: 1.55;
      font-size: 16px;
    }}
    code {{
      display: inline-block;
      padding: 6px 10px;
      border-radius: 10px;
      background: #f2eee5;
      color: #1b1b16;
      font-size: 18px;
      letter-spacing: 0.08em;
    }}
    .payload {{
      overflow-wrap: anywhere;
      font-size: 12px;
      color: #777267;
    }}
    .alternates {{
      margin-top: 12px;
      padding: 12px 14px;
      border-radius: 16px;
      background: #f8f3ea;
      color: #5d594f;
    }}
    .alternates ul {{
      margin: 8px 0 0;
      padding-left: 18px;
    }}
    .hint {{
      padding: 12px 14px;
      border-radius: 16px;
      background: #eaf6f0;
    }}
    @media (max-width: 720px) {{
      main {{
        grid-template-columns: 1fr;
      }}
    }}
  </style>
</head>
<body>
  <main>
    <section class="qr">
      <img src="{escape(qr_png_url)}" alt="AZMusic pairing QR code">
    </section>
    <section>
      <h1>Pair an AZMusic device</h1>
      <p>
        Use this first QR code to initialize the parent/admin device. After the
        parent device is connected, parents can generate separate student-device
        QR codes from the parent section.
      </p>
      <p><strong>Server:</strong> {escape(server_url)}</p>
      {opened_from_note}
      {alternate_urls_html}
      <p class="hint">
        If pairing times out, open the Server URL above in the phone/tablet
        browser. If it does not load, allow AZMusic/Python through Windows
        Firewall or make sure both devices are on the same Wi-Fi network.
      </p>
      <p><strong>Pairing code:</strong> <code>{escape(pairing_code)}</code></p>
      <p><strong>Expires UTC:</strong> {escape(expires_at)}</p>
      <p class="payload">{escape(pairing_uri)}</p>
    </section>
  </main>
</body>
</html>"""


def _gemini_success_html() -> str:
    return """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Gemini Connected</title>
  <style>
    body {
      font-family: "Segoe UI", sans-serif;
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      background: #f8f6f0;
      color: #1b1b16;
    }
    main {
      width: min(640px, calc(100vw - 32px));
      padding: 28px;
      background: white;
      border-radius: 24px;
      box-shadow: 0 18px 60px rgba(32, 28, 20, 0.14);
    }
  </style>
</head>
<body>
  <main>
    <h1>Gemini is connected</h1>
    <p>
      You can close this browser tab and return to AZMusic. Gemini vision
      review is now available for parent-triggered score correction after
      deterministic rendering.
    </p>
  </main>
</body>
</html>"""


def _gemini_error_html(message: str) -> str:
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Gemini Setup Needed</title>
  <style>
    body {{
      font-family: "Segoe UI", sans-serif;
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      background: #fff8f5;
      color: #1b1b16;
    }}
    main {{
      width: min(720px, calc(100vw - 32px));
      padding: 28px;
      background: white;
      border-radius: 24px;
      box-shadow: 0 18px 60px rgba(32, 28, 20, 0.14);
    }}
    code {{ overflow-wrap: anywhere; }}
  </style>
</head>
<body>
  <main>
    <h1>Gemini setup is not ready</h1>
    <p>{escape(message)}</p>
    <p>
      Install the AZMusic-owned Google OAuth client JSON on the server,
      restart AZMusic Server, then try again.
    </p>
  </main>
</body>
</html>"""
