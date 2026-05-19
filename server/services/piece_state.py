"""JSON-backed piece metadata and assignment state."""

import json
from pathlib import Path
from typing import Any

from server.config import settings
from server.models.orm import Piece, PieceStatus


class PieceStateService:
    def load(self, piece_id: str) -> dict[str, Any]:
        file_path = self._state_file(piece_id)
        if not file_path.exists():
            return {}
        return json.loads(file_path.read_text(encoding="utf-8"))

    def save(self, piece_id: str, state: dict[str, Any]) -> dict[str, Any]:
        file_path = self._state_file(piece_id)
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_text(
            json.dumps(state, indent=2, sort_keys=True),
            encoding="utf-8",
        )
        return state

    def upsert_metadata(
        self,
        piece_id: str,
        *,
        title: str,
        composer: str | None,
        primary_instrument: str | None = None,
        book_or_collection: str | None = None,
        visible_to_profile_ids: list[str] | None = None,
    ) -> dict[str, Any]:
        state = self.load(piece_id)
        state.update(
            {
                "title": title,
                "composer": composer,
                "primary_instrument": primary_instrument,
                "book_or_collection": book_or_collection,
                "normalized_title": _normalize_for_search(title),
                "normalized_composer": _normalize_for_search(composer or ""),
                "sort_title": _normalize_for_sort(title),
                "sort_composer": _normalize_for_sort(composer or ""),
            }
        )
        if visible_to_profile_ids is not None:
            state["visible_to_profile_ids"] = sorted(set(visible_to_profile_ids))
        else:
            state.setdefault("visible_to_profile_ids", [])
        return self.save(piece_id, state)

    def assign_profiles(self, piece_id: str, profile_ids: list[str]) -> dict[str, Any]:
        state = self.load(piece_id)
        visible_to_profile_ids = set(state.get("visible_to_profile_ids", []))
        visible_to_profile_ids.update(profile_ids)
        state["visible_to_profile_ids"] = sorted(visible_to_profile_ids)
        return self.save(piece_id, state)

    def metadata_for_piece(self, piece: Piece) -> dict[str, Any]:
        state = self.load(piece.id)
        return {
            "primary_instrument": state.get("primary_instrument"),
            "book_or_collection": state.get("book_or_collection"),
            "visible_to_profile_ids": state.get("visible_to_profile_ids", []),
            "library_status": _library_status_for_piece(piece),
            "normalized_title": state.get("normalized_title")
            or _normalize_for_search(piece.title),
            "normalized_composer": state.get("normalized_composer")
            or _normalize_for_search(piece.composer or ""),
            "sort_title": state.get("sort_title") or _normalize_for_sort(piece.title),
            "sort_composer": state.get("sort_composer")
            or _normalize_for_sort(piece.composer or ""),
        }

    def _state_file(self, piece_id: str) -> Path:
        return settings.storage_path / "piece_state" / f"{piece_id}.json"


def _library_status_for_piece(piece: Piece) -> str:
    if piece.status == PieceStatus.approved:
        return "ready"
    if piece.status == PieceStatus.review_pending:
        return "review"
    if piece.status == PieceStatus.processing:
        return "processing"
    return "intake"


def _normalize_for_search(value: str) -> str:
    return " ".join(
        "".join(char.lower() if char.isalnum() else " " for char in value).split()
    )


def _normalize_for_sort(value: str) -> str:
    normalized = _normalize_for_search(value)
    for prefix in ("the ", "a ", "an "):
        if normalized.startswith(prefix):
            return normalized.removeprefix(prefix)
    return normalized
