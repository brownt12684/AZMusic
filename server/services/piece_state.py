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
        processed_metadata: dict[str, Any] | None = None,
        piece_kind: str | None = None,
        source_book_id: str | None = None,
        source_page_start: int | None = None,
        source_page_end: int | None = None,
        catalog_metadata: dict[str, Any] | None = None,
        catalog_suggestions: list[dict[str, Any]] | None = None,
        validation_warnings: list[str] | None = None,
        split_confidence: float | None = None,
        notes: str | None = None,
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
        if processed_metadata is not None:
            state["processed_metadata"] = processed_metadata
        else:
            state.setdefault("processed_metadata", {})
        state["piece_kind"] = piece_kind or state.get("piece_kind") or "piece"
        if source_book_id is not None:
            state["source_book_id"] = source_book_id
        else:
            state.setdefault("source_book_id", None)
        if source_page_start is not None:
            state["source_page_start"] = source_page_start
        else:
            state.setdefault("source_page_start", None)
        if source_page_end is not None:
            state["source_page_end"] = source_page_end
        else:
            state.setdefault("source_page_end", None)
        if catalog_metadata is not None:
            state["catalog_metadata"] = catalog_metadata
        else:
            state.setdefault("catalog_metadata", {})
        if catalog_suggestions is not None:
            state["catalog_suggestions"] = catalog_suggestions
        else:
            state.setdefault("catalog_suggestions", [])
        if validation_warnings is not None:
            state["validation_warnings"] = validation_warnings
        else:
            state.setdefault("validation_warnings", [])
        if split_confidence is not None:
            state["split_confidence"] = split_confidence
        else:
            state.setdefault("split_confidence", None)
        if notes is not None:
            state["notes"] = notes
        else:
            state.setdefault("notes", None)
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
            "processed_metadata": state.get("processed_metadata", {}),
            "piece_kind": state.get("piece_kind") or "piece",
            "source_book_id": state.get("source_book_id"),
            "source_page_start": state.get("source_page_start"),
            "source_page_end": state.get("source_page_end"),
            "catalog_metadata": state.get("catalog_metadata", {}),
            "catalog_suggestions": state.get("catalog_suggestions", []),
            "validation_warnings": state.get("validation_warnings", []),
            "split_confidence": state.get("split_confidence"),
            "notes": state.get("notes"),
            "library_status": _library_status_for_piece(piece),
            "normalized_title": state.get("normalized_title") or _normalize_for_search(piece.title),
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
    if piece.status == PieceStatus.archived:
        return "archived"
    if piece.status == PieceStatus.review_pending:
        return "review"
    if piece.status == PieceStatus.processing:
        return "processing"
    return "intake"


def _normalize_for_search(value: str) -> str:
    return " ".join("".join(char.lower() if char.isalnum() else " " for char in value).split())


def _normalize_for_sort(value: str) -> str:
    normalized = _normalize_for_search(value)
    for prefix in ("the ", "a ", "an "):
        if normalized.startswith(prefix):
            return normalized.removeprefix(prefix)
    return normalized
