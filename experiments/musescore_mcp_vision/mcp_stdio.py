"""Minimal MCP stdio client used by the experiment harness.

The Python MCP SDK's stdio transport uses one JSON-RPC message per UTF-8 line.
It does not use LSP-style Content-Length framing.
"""

from __future__ import annotations

import asyncio
import json
import os
from dataclasses import dataclass
from typing import Any


class McpClientError(RuntimeError):
    """Raised when the MCP stdio server cannot be used."""


@dataclass(slots=True)
class McpToolCallResult:
    tool: str
    result: dict[str, Any]


class McpStdioClient:
    """Small JSON-RPC client for MCP servers launched over stdio."""

    def __init__(
        self,
        command: list[str],
        *,
        timeout_seconds: int = 30,
        env: dict[str, str] | None = None,
    ) -> None:
        if not command:
            raise McpClientError("mcp.server_command cannot be empty.")
        self.command = command
        self.timeout_seconds = timeout_seconds
        self.env = env or {}
        self.process: asyncio.subprocess.Process | None = None
        self._next_id = 1

    async def __aenter__(self) -> "McpStdioClient":
        self.process = await asyncio.create_subprocess_exec(
            *self.command,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env={**os.environ, **self.env},
        )
        await self.initialize()
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        if self.process and self.process.returncode is None:
            self.process.terminate()
            try:
                await asyncio.wait_for(self.process.wait(), timeout=5)
            except asyncio.TimeoutError:
                self.process.kill()
                await self.process.wait()

    async def initialize(self) -> None:
        await self.request(
            "initialize",
            {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {
                    "name": "azmusic-musescore-mcp-vision",
                    "version": "0.1.0",
                },
            },
        )
        await self.notify("notifications/initialized", {})

    async def list_tools(self) -> list[dict[str, Any]]:
        result = await self.request("tools/list", {})
        tools = result.get("tools")
        if not isinstance(tools, list):
            raise McpClientError("MCP server returned invalid tools/list result.")
        return [tool for tool in tools if isinstance(tool, dict)]

    async def call_tool(self, name: str, arguments: dict[str, Any]) -> McpToolCallResult:
        result = await self.request(
            "tools/call",
            {
                "name": name,
                "arguments": arguments,
            },
        )
        return McpToolCallResult(tool=name, result=result)

    async def notify(self, method: str, params: dict[str, Any]) -> None:
        await self._write_json({"jsonrpc": "2.0", "method": method, "params": params})

    async def request(self, method: str, params: dict[str, Any]) -> dict[str, Any]:
        request_id = self._next_id
        self._next_id += 1
        await self._write_json(
            {
                "jsonrpc": "2.0",
                "id": request_id,
                "method": method,
                "params": params,
            }
        )
        while True:
            try:
                message = await asyncio.wait_for(
                    self._read_json(),
                    timeout=self.timeout_seconds,
                )
            except asyncio.TimeoutError as exc:
                stderr = await self._stderr_tail()
                raise McpClientError(f"MCP {method} timed out. {stderr}") from exc
            if message.get("id") != request_id:
                continue
            if "error" in message:
                raise McpClientError(f"MCP {method} failed: {message['error']}")
            result = message.get("result")
            if not isinstance(result, dict):
                raise McpClientError(f"MCP {method} returned a non-object result.")
            return result

    async def _write_json(self, payload: dict[str, Any]) -> None:
        if not self.process or not self.process.stdin:
            raise McpClientError("MCP process is not running.")
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.process.stdin.write(body + b"\n")
        await self.process.stdin.drain()

    async def _read_json(self) -> dict[str, Any]:
        if not self.process or not self.process.stdout:
            raise McpClientError("MCP process is not running.")
        line = await self.process.stdout.readline()
        if not line:
            stderr = await self._stderr_tail()
            raise McpClientError(f"MCP process closed stdout. {stderr}")
        parsed = json.loads(line.decode("utf-8"))
        if not isinstance(parsed, dict):
            raise McpClientError("MCP response was not a JSON object.")
        return parsed

    async def _stderr_tail(self) -> str:
        if not self.process or not self.process.stderr:
            return ""
        try:
            data = await asyncio.wait_for(self.process.stderr.read(4096), timeout=0.2)
        except asyncio.TimeoutError:
            return ""
        if not data:
            return ""
        return data.decode("utf-8", errors="replace")
