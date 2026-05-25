# AZMusic V1 Delta Scope

Snapshot date: 2026-05-19

## Purpose

This document is the implementation contract for the next AZMusic v1 slice. It is a delta against the current working codebase, not a rebuild. Preserve the current routing, provider, repository, and offline-first structure unless a requirement below explicitly changes the UX or sync behavior.

When older mockups or notes disagree with current code, trust:

1. the preserved baseline in this document,
2. the current client and server code,
3. then older prototypes.

## Current Implementation Anchors

- Student library surface: `client/lib/presentation/screens/library/library_screen.dart` renders the student-only library from `studentLibraryEntriesProvider`, which already limits visibility to pieces that are both assigned to the active student and in `LibraryStatus.ready`.
- Parent intake, review, and push surface: `client/lib/presentation/screens/parent/parent_home_screen.dart` uses `PieceListNotifier.importToIntake()`, `parentReviewQueueProvider`, and `PieceListNotifier.pushToProfile()` to keep parent work centered in one hub.
- Piece detail surface: `client/lib/presentation/screens/piece_detail/piece_detail_screen.dart` is the existing bridge between library rows and the reader, and it already exposes every stored score version for a piece.
- Reader surface: `client/lib/presentation/screens/reader/reader_screen.dart` keeps `About this piece`, media, tuner, notes, page navigation, and score markup inside a single reader route.
- Local persistence boundary: `LocalLibraryRepository` copies score files into `library/scores/<piece_id>/` and indexes them in `library/library_index.json`; `AnnotationRepository` persists page markup in `annotations/<profile_id>/<score_version_id>/page_<n>.json`.
- Server-backed scaffolding already present: the client and tests already target `/api/v1/pieces/import`, `/api/v1/review`, `/api/v1/pieces/{id}/push`, and `/api/v1/sync/{client_id}`. Extend this scaffolding instead of inventing a second workflow contract.
- Server processing boundary now present: `/api/v1/processing` exposes settings, validation, capability reporting, and device-worker registration; `ScoreProcessingService` preserves raw PDFs and delegates MusicXML/PDF creation to engine adapters.

## Baseline To Preserve

### Student flow

- Student login still opens the student library directly.
- The student library still shows only pieces that are both:
  - visible to the active student profile, and
  - in `LibraryStatus.ready`.
- Search, browse tabs (`Title`, `Composer`, `Book`, `Recent`), status badges, and piece detail routing remain present.
- Opening a library item still routes through piece detail and then into the reader.

### Parent flow

- Parent login remains PIN-gated.
- Parent home remains the intake and review hub.
- Parent import continues to create local intake entries immediately.
- Parent import remains best-effort online after the local intake write. A failed upload must not remove the intake entry.
- Parent review remains approval-focused.
- Parent push continues to assign approved pieces to one or more student profiles.
- Parent push remains local-first today: the client updates local visibility immediately and retries the server push later if the server is unreachable.

### Reader flow

- The reader still opens locally stored PDF and image scores.
- Horizontal page navigation remains the primary reading gesture in read mode.
- Piece detail still lists stored score versions and allows opening any stored version.
- `About this piece`, media, tuner, and notes remain reader-level functions instead of separate top-level destinations.
- The current reader remains one route with internal panels and overlays, not a family of separate reader subroutes.

### Notes and markup flow

- Student mode still supports:
  - toggling the notes layer,
  - entering draw mode,
  - clearing page markup,
  - adding typed notes,
  - editing and deleting typed notes.
- Markup stays page-specific.
- Typed notes stay tied to the active piece and score version, with page tagging.
- Parent mode stays read/review oriented and does not gain student annotation tools by default.

### Local-first behavior

- Imported source files continue to be copied into app-managed local storage.
- Local reading must continue to work with no server connection.
- Raw imports remain readable immediately after import.
- Raw score access remains available even after a processed or approved version exists.
- `LocalLibraryRepository` remains the current persistence boundary for imported files and library metadata unless a later worker swaps the implementation behind the same contract.
- Page markup remains persisted per profile, per score version, and per page number. Any sync or approved-version work must respect that storage model.
- Opportunistic client/server wiring already exists in `PieceListNotifier` and `ServerPieceSyncRepository`; network failure must continue to degrade to local-only behavior instead of blocking the user.
- The server-backed import, review, push, and sync scaffolding must stay recognizable to later workers and tests even if the client wiring improves in this slice.
- Server-side OMR/rendering configuration must stay server-owned. The Flutter app may expose parent settings and status, but Audiveris, MuseScore, fallback, provenance, and device-worker dispatch decisions belong behind server APIs.

## Delta Mapped To Existing Architecture

### Student library and library rail

- Current anchor: `LibraryScreen` already supports `Title`, `Composer`, `Book`, and `Recent` browse modes, plus search-first filtering over the student-ready library list.
- Delta work: move the existing alphabet rail to the left and change it from tap-only letter filtering to touch-drag jump navigation within the already filtered result set.
- Preserve: the student still only sees `LibraryStatus.ready` pieces, `Recent` stays non-alphabetical, and library rows still route through piece detail before the reader.

### Parent intake, review, and push

- Current anchor: `ParentHomeScreen`, `PieceListNotifier.importToIntake()`, `parentReviewQueueProvider`, and `PieceListNotifier.pushToProfile()` already define the parent workflow boundary.
- Delta impact: none of the requested library, reader, write-mode, or sync changes should bypass or replace the parent intake/review/push sequence.
- Preserve: parent PIN login, local intake creation, server-backed review queue loading, approval flow, and approved-piece push semantics remain the gate for student visibility.

### Reader chrome and focus

- Current anchor: `ReaderScreen` uses a permanent left rail, a fixed-width module panel, and a top bar above the score canvas.
- Delta work: reclaim horizontal score space by collapsing or hiding secondary chrome while keeping the same in-reader destinations for About, media, tuner, and notes.
- Preserve: piece detail still chooses the score version before the reader opens, the reader still stays in one route, and the page-position cue remains visible even when chrome is minimized.

### Write mode and annotation flow

- Current anchor: student-only score markup already lives behind `annotationPageProvider`, `AnnotationRepository`, and the notes module draw toggle.
- Delta work: promote drawing into an explicit reader mode with visible state and unambiguous gesture ownership instead of leaving that contract implicit inside the notes panel.
- Preserve: read mode keeps swipe/page-turn behavior, write mode owns drag gestures on the score, hiding the notes layer does not delete strokes, typed notes remain page-tagged, and parent mode stays review-oriented.

### Two-page landscape reading

- Current anchor: PDFs currently open through `SfPdfViewer.file` in single-page horizontal mode, image scores stay single-page, and markup is keyed to one concrete page number.
- Delta work: add PDF-only landscape spreads without changing portrait behavior, without changing image behavior, and without turning annotation storage into a spread-level model.
- Preserve: entering write mode from a spread still resolves to one active page, typed notes and page markup stay page-specific, and raw/approved score-version switching still happens through the existing piece-detail plus reader path.

### Sync and connectivity

- Current anchor: `PieceListNotifier` already does best-effort upload after import, fetches assigned server pieces for the active student, merges remote piece metadata, and downloads approved PDF versions when reachable.
- Delta work: make sync triggers and banner state real while keeping them opportunistic, non-blocking, and additive to the current local-first flow.
- Preserve: local import remains immediately usable, server outages still fall back to the local library, remote approved versions must not remove raw fallback access, and review/push continue to control what becomes student-visible.

### Server processing and configuration

- Current anchor: `/api/v1/processing`, `ProcessingSettingsStore`, `DeviceWorkerRegistry`, `MusicXmlEngine`, `AudiverisMusicXmlEngine`, `MuseScoreRenderEngine`, and `ScoreProcessingService` already separate frontend status/configuration from backend processing.
- Delta work: install/configure real Audiveris and MuseScore in the target environment, tighten MusicXML validation as real outputs arrive, and add an actual dispatch loop before device workers process work packages.
- Preserve: raw imports remain stored and readable, failed required processing records a job failure instead of deleting the raw file, parent approval remains the gate before processed artifacts replace the student default, and the deterministic stub remains a development fallback only when explicitly enabled.

## Requested Delta

### 1. Library rail

- Move the alphabet rail from the right side of the student library to the left side.
- The rail must support touch-drag scrubbing, not only discrete taps.
- Dragging across letters should continuously update the active jump target while the finger or stylus stays down.
- The rail applies to sortable alphabetical modes only: `Title`, `Composer`, and `Book`.
- The rail stays hidden or disabled in `Recent`.
- Search filtering still applies before alphabet jumping. The rail jumps within the current filtered result set, not the full unfiltered library.
- The change is a navigation refinement only. It must not change which pieces are visible to the student or how parent intake works.

### 2. Reader chrome and focus

- The reader must give more horizontal space to the score by default.
- Secondary reader chrome should be collapsible or hidden when inactive rather than permanently consuming score width.
- Opening `About this piece`, media, tuner, or notes must stay in-reader and must not navigate away from the reading context.
- The reader must still expose page position clearly enough that a student can recover orientation after hiding chrome.

### 3. Write mode

- Writing on top of the score must become an explicit mode, not an ambiguous side effect of touching the page.
- In read mode:
  - horizontal swipe owns the page-turn gesture,
  - drawing is off.
- In write mode:
  - annotation input owns drag gestures on the score,
  - page swipe is suppressed on the annotated surface.
- Exiting write mode restores normal swipe navigation immediately.
- The UI must make it obvious whether the reader is in read mode or write mode.
- Entering write mode must never erase existing strokes.
- Hiding the notes layer must hide saved and active markup without deleting it.

### 4. Two-page landscape reading

- Wide landscape reading should support a two-page spread for PDF scores.
- Portrait remains single-page.
- Image scores remain single-page.
- Single-page PDFs remain single-page.
- Two-page mode is for reading, not ambiguous dual-page annotation.
- Entering write mode from a two-page spread must fall back to single-page annotation on the active page.
- Exiting write mode may return to the previous two-page read layout if the device is still eligible for it.
- Spread navigation advances by spread in two-page mode.
- Page position UI must reflect spread context clearly, for example `1-2 of 6` rather than only one page number.

### 5. Sync and connectivity

- Local import remains the source of truth for immediate usability. Sync is opportunistic and non-blocking.
- The app should attempt sync on the main moments that matter for this slice:
  - app launch or foreground return,
  - manual refresh,
  - after a local import,
  - after a parent push or approval event,
  - after connectivity returns.
- Student devices should download newly assigned ready pieces and newly approved default score versions when the server is reachable.
- Sync must not create duplicate local pieces when a remote piece is already linked to an existing local entry.
- A remote approved score version should become available locally without removing the raw fallback.
- Banner and status copy should reflect real state instead of permanent placeholder text.
- At minimum this slice must distinguish:
  - offline but usable from cache,
  - sync in progress,
  - sync completed with no blocking issue,
  - sync failed but local content remains usable.

### 6. Server processing and backend configuration

- The server owns all score-processing orchestration, settings, artifact paths, job status, candidate metadata, warnings, and provenance.
- Parent tools must be able to view and update Audiveris and MuseScore paths without hard-coding those paths in client code.
- Audiveris is the first real OMR backend for MusicXML generation.
- MuseScore CLI is the first real backend for rendering MusicXML review PDFs.
- If Audiveris is missing and stub fallback is enabled, generated MusicXML must be clearly marked as stub/prototype provenance.
- If Audiveris is required and unavailable, the raw PDF must remain stored, the job must fail visibly, and the app must not pretend a real MusicXML candidate exists.
- Experimental device workers may register capabilities, but work produced by a device still goes through server intake, parent review, and approval before becoming student-visible.

## Edge Cases And Conflict Rules

### Offline and online behavior

- Import while offline:
  - the score opens locally immediately,
  - the piece remains readable,
  - the pending server upload retries later without requiring re-import.
- Network loss during sync:
  - must not remove local pieces,
  - must not clear queued sync intent,
  - must not corrupt current reader state.
- Server unavailable at launch:
  - the library still loads from local storage,
  - the banner reports offline-ready state rather than blocking the screen.
- Remote approved update arrives later:
  - the approved version can become the default local reading version,
  - the raw source version remains accessible,
  - existing local typed notes and markup are not silently deleted.

### Write mode and swipe conflicts

- A single gesture cannot both turn pages and ink the score.
- Read mode owns swipe. Write mode owns drag.
- If a reader subpanel opens while write mode is active, the implementation must avoid hidden gesture capture. The safest acceptable behavior is:
  - keep write mode visibly active, or
  - exit write mode automatically and clearly.
- Parent profiles do not enter student write mode unless that behavior is explicitly added later.

### Landscape two-page reading

- Odd page counts must still render sensibly. The last spread may end with a single trailing page.
- If the current page in single-page mode becomes the left page of a spread, the reader should keep the user near the same musical location rather than jumping back to the beginning.
- Switching between portrait single-page and landscape two-page must preserve reading position as closely as practical.
- Write mode in landscape must target one concrete page, not an ambiguous spread-level canvas.

### Library rail behavior

- If the current search query leaves no items under a dragged letter, the UI should remain stable and show the filtered empty or sparse result state instead of snapping unpredictably.
- Dragging across letters with no matching rows must not throw, freeze scrolling, or block normal list interaction after release.
- The left rail must not cover the first characters of row titles or make list rows harder to tap.

## Open Decisions For Implementers

- PDF spread strategy: the current reader is built around `SfPdfViewer.file` in single-page horizontal mode. Decide whether two-page spreads can stay inside that viewer or need an adapter/custom layout, but do not use this requirement as a reason to replace the reader route or annotation storage model.
- Spread anchoring rule: confirm whether landscape spreads are always `1-2`, `3-4`, and so on, or whether a cover-style singleton first page exists. Keep page-position copy and write-mode fallback consistent with the chosen rule.
- Annotation carry-forward on approved downloads: markup is currently keyed by `scoreVersionId`. Decide whether existing markup stays only on the raw import, is copied forward, or is remapped deliberately when an approved PDF becomes default. Do not silently discard or auto-rebind it.
- Image-import sync scope: the local client can import image scores, but the current server import path only processes PDFs. Decide whether image-only imports remain local-only in this delta or whether the server contract expands with them.
- Sync durability source: decide whether queued upload/download intent for this slice lives only in client persistence, in expanded `/api/v1/sync` state, or both. This choice affects `client`, `server`, and future database work.
- Status source of truth: `LibrarySyncBannerState`, `syncStatusProvider`, and `connectionStatusProvider` now expose real client-owned sync states. Decide whether future banner copy should remain client-owned or move onto the server `/api/v1/sync` contract before wiring the same copy across multiple screens.

## Acceptance Criteria

1. A concise worker-facing spec exists for the library, reader, write-mode, two-page, and sync delta.
2. Student login, parent PIN login, parent intake/review/push, piece detail, reader, typed notes, and page markup baseline behaviors are explicitly preserved.
3. The student library alphabet rail is defined as left-sided and touch-drag optimized, while `Recent` remains non-alphabetical.
4. Reader behavior distinguishes read mode from write mode, with swipe ownership and ink ownership documented unambiguously.
5. The two-page landscape rule is documented, including its interaction with PDF-only support, portrait fallback, and write-mode fallback to single-page annotation.
6. Offline import, offline reading, deferred sync retry, online assignment download, and approved-version download behaviors are documented as non-blocking local-first flows.
7. The contract states that approved or processed updates must not remove raw fallback access.
8. The contract documents edge cases for offline or online transitions, write-mode gesture conflicts, and landscape spread behavior.
9. Open cross-folder decisions around spread implementation, approved-version annotation handling, image-import sync expectations, and sync-state ownership are called out explicitly for implementers.
10. Backend processing is explicitly treated as an existing server-side extension point, not a frontend rebuild: settings/capabilities are exposed to parents, real OMR/rendering engines sit behind server adapters, and raw imports remain preserved on processing failure.

## Out Of Scope For This Delta

- Replacing the current client architecture or route structure.
- Rebuilding parent review UX beyond what is needed to preserve the current flow.
- Full notation editing.
- Cloud or WAN assumptions.
- Any change that makes the server required for basic reading of already imported or already synced content.

## Code Anchor Verification

Verified: 2026-05-20

All 10 `AppKeys` anchors in `client/lib/presentation/screens/reader/reader_screen.dart` were verified against the source file. Every anchor matches its documented line number exactly.

| Anchor | Documented Line | Verified Line | Status |
|---|---|---|---|
| `AppKeys.readerScreen` | 117 | 117 | ✓ Match |
| `AppKeys.aboutModuleButton` | 436 | 436 | ✓ Match |
| `AppKeys.mediaModuleButton` | 442 | 442 | ✓ Match |
| `AppKeys.tunerModuleButton` | 453 | 453 | ✓ Match |
| `AppKeys.notesModuleButton` | 459 | 459 | ✓ Match |
| `AppKeys.notesLayerVisibilityToggle` | 871 | 871 | ✓ Match |
| `AppKeys.notesDrawModeToggle` | 894 | 894 | ✓ Match |
| `AppKeys.notesClearPageButton` | 912 | 912 | ✓ Match |
| `AppKeys.notesComposerField` | 936 | 936 | ✓ Match |
| `AppKeys.noteCard` | 1084 | 1084 | ✓ Match |

No refinements to scope are needed based on this verification. The anchors are stable and reliable for test automation.
