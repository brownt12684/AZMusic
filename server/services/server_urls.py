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
    return reachable_server_urls(request)[0]


def reachable_server_urls(request: Request) -> list[str]:
    """Return candidate URLs clients can try when claiming a QR pairing code."""
    configured_url = settings.public_server_url.strip().rstrip("/")
    if configured_url:
        return [configured_url]

    request_url = str(request.base_url).rstrip("/")
    request_host = (request.url.hostname or "").lower()
    parsed = urlsplit(request_url)
    port = parsed.port
    scheme = parsed.scheme

    if request_host and request_host not in _LOCAL_HOSTNAMES:
        urls = [request_url]
        urls.extend(_urls_for_ipv4_candidates(scheme=scheme, port=port))
        return _compact_urls(urls)

    urls = _urls_for_ipv4_candidates(scheme=scheme, port=port)
    if not urls:
        urls.append(request_url)
    return _compact_urls(urls)


def _urls_for_ipv4_candidates(*, scheme: str, port: int | None) -> list[str]:
    urls: list[str] = []
    for lan_ip in detect_lan_ipv4_candidates():
        netloc = lan_ip
        if port is not None:
            netloc = f"{lan_ip}:{port}"
        urls.append(urlunsplit((scheme, netloc, "", "", "")).rstrip("/"))
    return urls


def detect_lan_ipv4() -> str | None:
    """Best-effort LAN IPv4 detection without adding a platform dependency."""
    candidates = detect_lan_ipv4_candidates()
    if candidates:
        return candidates[0]
    return None


def detect_lan_ipv4_candidates() -> list[str]:
    """Best-effort LAN IPv4 candidates ordered by likely client reachability."""
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

    return [str(address) for address in _select_reachable_ipv4_candidates(candidates)]


def _select_reachable_ipv4(candidates: list[str]) -> str | None:
    selected = _select_reachable_ipv4_candidates(candidates)
    if selected:
        return str(selected[0])
    return None


def _select_reachable_ipv4_candidates(candidates: list[str]) -> list[ipaddress.IPv4Address]:
    usable_addresses: list[ipaddress.IPv4Address] = []
    seen: set[ipaddress.IPv4Address] = set()
    for candidate in candidates:
        try:
            address = ipaddress.ip_address(candidate)
        except ValueError:
            continue

        if not isinstance(address, ipaddress.IPv4Address):
            continue
        if address.is_loopback or address.is_link_local or address.is_unspecified:
            continue
        if address in seen:
            continue
        seen.add(address)
        usable_addresses.append(address)

    if not usable_addresses:
        return []

    # Prefer common home/LAN ranges over 172.16/12, which is frequently a
    # virtualized adapter address during Windows Sandbox smoke tests.
    return sorted(usable_addresses, key=_address_priority)


def _address_priority(address: ipaddress.IPv4Address) -> tuple[int, int]:
    text = str(address)
    if text.startswith("192.168."):
        private_priority = 0
    elif text.startswith("10."):
        private_priority = 1
    elif address.is_private and text.startswith("172."):
        private_priority = 2
    elif address.is_private:
        private_priority = 3
    else:
        private_priority = 4
    return (private_priority, int(address))


def _compact_urls(urls: list[str]) -> list[str]:
    compacted: list[str] = []
    seen: set[str] = set()
    for url in urls:
        normalized = url.strip().rstrip("/")
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        compacted.append(normalized)
    return compacted
