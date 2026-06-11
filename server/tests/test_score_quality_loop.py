from server.services.score_quality_loop import (
    build_hybrid_fallback_candidate,
    build_quality_loop_summary,
)


def test_quality_loop_summary_and_hybrid_fallback_candidate() -> None:
    measure_reviews = [
        {"status": "rejected", "target": {"part_id": "P1", "staff": "2"}},
        {"status": "accepted", "target": {"part_id": "P1", "staff": "1"}},
    ]
    visual_diff = {
        "original_alignment": [
            {"changed_pixel_ratio": 0.25},
            {"changed_pixel_ratio": 0.1},
        ]
    }

    summary = build_quality_loop_summary(
        outcome="hybrid_fallback",
        measure_reviews=measure_reviews,
        visual_diff=visual_diff,
    )
    candidate = build_hybrid_fallback_candidate(
        candidate_id="hybrid_fallback_test",
        raw_score_version_id="raw-1",
        rendered_score_version_id="rendered-1",
        canonical_score_version_id="canonical-1",
        notation_findings=[{"finding_id": "f1"}],
        measure_reviews=measure_reviews,
        visual_diff=visual_diff,
        reason="No verified edit was accepted.",
    )

    assert summary["accepted_edit_count"] == 1
    assert summary["rejected_edit_count"] == 1
    assert summary["visual_similarity"] == 0.75
    assert summary["requires_parent_review"] is True
    assert candidate["engine_name"] == "hybrid_fallback"
    assert candidate["score_version_id"] == "raw-1"
    assert candidate["source_rendered_score_version_id"] == "rendered-1"
    assert candidate["hybrid_fallback_regions"][0]["unresolved_targets"] == [
        {"part_id": "P1", "staff": "2"}
    ]
