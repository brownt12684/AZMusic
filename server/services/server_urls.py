"""Helpers for generating device-reachable server URLs."""

from __future__ import annotations

import ipaddress
import socket
from urllib.parse import urlsplit, urlunsplit

from fastapi import Request

from server.config import settings

_LOCAL_HOSTNAMES = {"localhost", "127.0.0.1", "::1", "0.0.0.0"}


def reachable_server_url(request: Request) -> str:
    """Return the URL clients should use when claiming a QR pairing code."""
    configured_url = settings.public_server_url.strip().rstrip("/")
    if configured_url:
        return configured_url

    request_url = str(request.base_url).rstrip("/")
    request_host = (request.url.hostname or "").lower()
    if request_host and request_host not in _LOCAL_HOSTNAMES:
        return request_url

    lan_ip = detect_lan_ipv4()
    if lan_ip is None:
        return request_url

    parsed = urlsplit(request_url)
    netloc = lan_ip
    if parsed.port is not None:
        netloc = f"{lan_ip}:{parsed.port}"
    return urlunsplit((parsed.scheme, netloc, "", "", "")).rstrip("/")


def detect_lan_ipv4() -> str | None:
    """Best-effort LAN IPv4 detection without adding a platform dependency."""
    candidates: list[str] = []

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp_socket:
            udp_socket.connect(("8.8.8.8", 80))
            candidates.append(udp_socket.getsockname()[0])
    except OSError:
        pass

    try:
        hostname = socket.gethostname()
        candidates.extend(socket.gethostbyname_ex(hostname)[2])
    except OSError:
        pass

    try:
        hostname = socket.gethostname()
        for result in socket.getaddrinfo(hostname, None, socket.AF_INET):
            candidates.append(result[4][0])
    except OSError:
        pass

    return _select_reachable_ipv4(candidates)


def _select_reachable_ipv4(candidates: list[str]) -> str | None:
    usable_addresses: list[ipaddress.IPv4Address] = []
    for candidate in candidates:
        try:
            address = ipaddress.ip_address(candidate)
        except ValueError:
            continue

        if not isinstance(address, ipaddress.IPv4Address):
            continue
        if address.is_loopback or address.is_link_local or address.is_unspecified:
            continue
        usable_addresses.append(address)

    private_addresses = [
        address for address in usable_addresses if address.is_private
    ]
    if private_addresses:
        return str(private_addresses[0])
    if usable_addresses:
        return str(usable_addresses[0])
    return None

