"""Score quality-loop result helpers.

The actual correction loop lives at the review-service boundary because it needs
LLM, MCP, database, and renderer dependencies. This module keeps the loop result
shape stable and testable.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(slots=True)
class ScoreQualityLoopConfig:
    max_seconds: int = 1800
    target: str = "readable_visual_match"
    fallback_policy: str = "hybrid_candidate"


def build_quality_loop_summary(
    *,
    outcome: str,
    measure_reviews: list[dict[str, Any]],
    visual_diff: dict[str, Any] | None,
    config: ScoreQualityLoopConfig | None = None,
) -> dict[str, Any]:
    loop_config = config or ScoreQualityLoopConfig()
    accepted_reviews = [
        review for review in measure_reviews if review.get("status") == "accepted"
    ]
    rejected_reviews = [
        review for review in measure_reviews if review.get("status") == "rejected"
    ]
    return {
        "target": loop_config.target,
        "fallback_policy": loop_config.fallback_policy,
        "max_seconds": loop_config.max_seconds,
        "outcome": outcome,
        "accepted_edit_count": len(accepted_reviews),
        "rejected_edit_count": len(rejected_reviews),
        "requires_parent_review": outcome != "verified_musicxml",
        "visual_similarity": _visual_similarity(visual_diff),
        "visual_diff": visual_diff,
    }


def build_hybrid_fallback_candidate(
    *,
    candidate_id: str,
    raw_score_version_id: str,
    rendered_score_version_id: str,
    canonical_score_version_id: str,
    notation_findings: list[dict[str, Any]],
    measure_reviews: list[dict[str, Any]],
    visual_diff: dict[str, Any] | None,
    reason: str,
) -> dict[str, Any]:
    unresolved_targets = [
        review.get("target")
        for review in measure_reviews
        if review.get("status") == "rejected" and isinstance(review.get("target"), dict)
    ]
    return {
        "candidate_id": candidate_id,
        "label": "Hybrid fallback: original PDF retained",
        "engine_name": "hybrid_fallback",
        "engine_version": "local_llm_verified_quality_loop",
        "provenance": "original_pdf_with_unresolved_musicxml",
        "confidence": 0.0,
        "raw_score_version_id": raw_score_version_id,
        "score_version_id": raw_score_version_id,
        "source_rendered_score_version_id": rendered_score_version_id,
        "canonical_score_version_id": canonical_score_version_id,
        "hybrid_display_mode": "original_pdf_full_page",
        "hybrid_fallback_reason": reason,
        "hybrid_fallback_regions": [
            {
                "page": 1,
                "region": "full_page",
                "reason": reason,
                "unresolved_targets": unresolved_targets,
            }
        ],
        "llm_notation_findings": list(notation_findings or []),
        "llm_measure_reviews": list(measure_reviews or []),
        "llm_visual_diff": visual_diff,
        "llm_correction_scope": "hybrid_fallback",
        "render_validation_status": "valid",
        "warnings": [
            "No verified MusicXML correction was accepted; the original PDF remains "
            "the safe fallback."
        ],
        "selected": False,
    }


def _visual_similarity(visual_diff: dict[str, Any] | None) -> float | None:
    if not isinstance(visual_diff, dict):
        return None
    alignment = visual_diff.get("original_alignment")
    if not isinstance(alignment, list) or not alignment:
        return None
    ratios = [
        float(item.get("changed_pixel_ratio"))
        for item in alignment
        if isinstance(item, dict) and item.get("changed_pixel_ratio") is not None
    ]
    if not ratios:
        return None
    return max(0.0, min(1.0, 1.0 - max(ratios)))
