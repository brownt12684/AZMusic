# AZMusic V1 Delta Implementation Checklist

Snapshot date: 2026-05-19

## Code Anchor Verification Status

Verified: 2026-05-20

All 10 `AppKeys` anchors in `client/lib/presentation/screens/reader/reader_screen.dart` match their documented line numbers exactly. These anchors are stable and safe for test automation.

| Anchor | Line | Status |
|---|---|---|
| `AppKeys.readerScreen` | 117 | ✓ VERIFIED |
| `AppKeys.aboutModuleButton` | 436 | ✓ VERIFIED |
| `AppKeys.mediaModuleButton` | 442 | ✓ VERIFIED |
| `AppKeys.tunerModuleButton` | 453 | ✓ VERIFIED |
| `AppKeys.notesModuleButton` | 459 | ✓ VERIFIED |
| `AppKeys.notesLayerVisibilityToggle` | 871 | ✓ VERIFIED |
| `AppKeys.notesDrawModeToggle` | 894 | ✓ VERIFIED |
| `AppKeys.notesClearPageButton` | 912 | ✓ VERIFIED |
| `AppKeys.notesComposerField` | 936 | ✓ VERIFIED |
| `AppKeys.noteCard` | 1084 | ✓ VERIFIED |

## Purpose

This note translates `docs/V1_DELTA_SCOPE.md` into an implementation checklist tied to the current codebase. It is a delta only. Extend the current student, parent, library, piece-detail, reader, and local-first sync flows without replacing the existing route, provider, repository, or offline-first structure.

## Preserved baseline and extension points

- Student library remains `client/lib/presentation/screens/library/library_screen.dart` backed by `studentLibraryEntriesProvider` in `client/lib/presentation/providers/piece_providers.dart`.
- Student login still lands in the student library, and parent login remains a separate parent-tools entry flow.
- Student visibility rules remain unchanged: only pieces visible to the active student and in `LibraryStatus.ready` appear in the student library.
- Parent intake, review, and push remain centered in `client/lib/presentation/screens/parent/parent_home_screen.dart`.
- Parent import still creates a local intake entry immediately before any server-side processing succeeds.
- Piece detail remains the handoff between library browsing and score reading in `client/lib/presentation/screens/piece_detail/piece_detail_screen.dart`.
- Piece detail still exposes stored score versions, and the reader can still open any stored local version from that screen.
- Reader utilities remain inside `client/lib/presentation/screens/reader/reader_screen.dart`; `About this piece`, media, tuner, and notes do not become separate routes.
- Typed notes and page markup remain local-first and tied to profile, piece or score version, and page through the current note and annotation repositories.
- Local score access remains available from app-managed storage even when the server is unavailable.

## Client checklist

### 1. Library rail

Extends the current student `LibraryScreen` tabs, search field, and piece-detail routing. It does not change which pieces appear in the library or how parent intake works.

- [ ] Preserve the existing browse tabs (`Title`, `Composer`, `Book`, `Recent`) and the current search-first filtering pipeline in `library_screen.dart`.
- [ ] Keep `studentLibraryEntriesProvider` as the source of truth for student-visible ready pieces.
- [ ] Replace the current trailing tap-only `_VerticalAlphaRail` with a leading rail that supports continuous touch or stylus drag scrubbing.
- [ ] Change the current `_alphaJump` behavior from "filter the list to a starting letter" to "jump or scroll within the already filtered and sorted list" so navigation is refined without changing result visibility.
- [ ] Keep the rail enabled only for `Title`, `Composer`, and `Book`; keep `Recent` hidden or disabled.
- [ ] Ensure the left rail does not cover row titles, reduce tap targets, or interfere with pull-to-refresh.

### 2. Reader chrome and focus

Extends the current `ReaderScreen` layout, which already keeps the module rail and module content in-reader. It does not turn reader tools into separate destinations.

- [ ] Keep `ReaderScreen` as the single reading route opened from piece detail.
- [ ] Keep module selection in-reader; opening `About this piece`, media, tuner, or notes must not replace the reader route.
- [ ] Reduce permanent chrome width by making the reader rail, module panel, or secondary controls collapsible when inactive.
- [ ] Preserve a clear page-position indicator while chrome is collapsed so the student can recover orientation quickly.
- [ ] Keep piece title, version context, and page navigation available without reintroducing a full-width persistent sidebar.

### 3. Write mode and gesture ownership

Extends the current student annotation path in `ReaderScreen` plus `annotationPageProvider`. It does not add annotation tools to parent mode.

- [ ] Keep annotation persistence keyed to the existing profile, score version, and page model in `annotation_providers.dart` and the annotation repository.
- [ ] Promote the existing draw toggle into explicit read mode versus write mode language in the reader UI.
- [ ] In read mode, preserve horizontal page navigation as the default gesture on the score surface.
- [ ] In write mode, let annotation input own drag gestures on the score surface and suppress page swipes on that annotated surface.
- [ ] Exiting write mode must immediately restore normal swipe navigation without clearing saved strokes.
- [ ] Hiding the notes layer must hide saved and active markup without deleting persisted annotation data.
- [ ] If a reader subpanel opens while write mode is active, choose one explicit rule and apply it consistently: keep write mode visibly active, or exit it clearly.

### 4. Two-page landscape reading

Extends the existing PDF reader path in `ReaderScreen`. It does not change image-score behavior, portrait behavior, or piece-detail version selection.

- [ ] Keep portrait reading single-page.
- [ ] Keep image scores single-page regardless of orientation.
- [ ] Add spread behavior only for eligible PDF scores in wide landscape.
- [ ] Preserve current reading position as closely as practical when switching between portrait single-page and landscape two-page.
- [ ] Show spread-aware position copy such as `1-2 of 6` instead of a single page number when two-page mode is active.
- [ ] Entering write mode from a spread must resolve to one concrete page and fall back to single-page annotation.
- [ ] Exiting write mode may restore the previous spread layout if orientation and score type are still eligible.

### 5. Sync UX and local-first behavior

Extends the existing local repository flow, `PieceListNotifier`, `ServerPieceSyncRepository`, and the current sync banner providers. It does not make server connectivity required for reading imported or cached scores.

- [ ] Keep local import completion first: a newly imported score remains readable before any upload succeeds.
- [ ] Keep piece detail able to open any stored local score version, including the raw fallback.
- [x] `syncStatusProvider` and `connectionStatusProvider` now expose explicit user-facing states for offline-ready, syncing, synced, and sync-failed-but-usable through `LibrarySyncBannerState`.
- [ ] Decide how much of that banner state should stay client-owned versus being mirrored from the server `/api/v1/sync` contract.
- [ ] Trigger sync attempts on app launch or foreground return, manual refresh, post-import, post-approval or push, and connectivity return.
- [ ] Keep student download behavior additive: newly assigned ready pieces and newly approved default score versions download locally without removing raw local versions.
- [ ] Keep remote merge behavior idempotent against `serverPieceId` and existing local score-version links so sync does not duplicate local pieces.

## Server checklist

### 0. Processing settings and engine boundary

Extends the current `/api/v1/pieces/import`, `/api/v1/jobs`, and `/api/v1/review` flow. It does not move processing decisions into the Flutter UI.

- [x] Add `/api/v1/processing/settings` for durable Audiveris, MuseScore, processing mode, and stub-fallback settings.
- [x] Add `/api/v1/processing/settings/validate` and `/api/v1/processing/capabilities` for parent-visible executable and backend status.
- [x] Add experimental `/api/v1/processing/device-workers/register` and `/api/v1/processing/device-workers` endpoints.
- [x] Introduce server-side engine adapters for MusicXML generation and review-PDF rendering.
- [x] Route PDF import through the engine adapters while preserving raw PDFs and the existing parent review/push flow.
- [x] Mark stub-generated MusicXML with explicit provenance and warnings instead of presenting it as real OMR output.
- [x] Preserve the raw import and mark the job failed when required processing is unavailable.
- [x] Extract processed MusicXML metadata and attach it to review candidates, job results, piece detail responses, and client local piece records.
- [ ] Add parent-editable metadata correction fields for processed MusicXML metadata before push to student devices.
- [ ] Add researched piece metadata, such as composer/work context and pedagogical notes, as a separate reviewed backend result rather than mixing it into raw MusicXML extraction.
- [ ] Install/configure Audiveris in the target environment and validate real PDF-to-MusicXML output.
- [ ] Install/configure MuseScore CLI in the target environment and validate real MusicXML-to-PDF rendering.
- [ ] Add a real device-worker dispatch and result-upload loop before treating on-device processing as more than registration/capability scaffolding.

### 1. Assigned-piece and score-version sync

Extends the current `/api/v1/pieces`, `/api/v1/pieces/assigned/{profile_id}`, and `/api/v1/pieces/{piece_id}/push` surface. It does not redefine the current router layout.

- [ ] Keep `/api/v1/pieces/{piece_id}` as the detail source for title, visibility, library status, and score-version metadata.
- [x] Include extracted processed metadata in piece summary/detail responses so clients can sync and display it without refetching review items.
- [ ] Ensure approved default score-version metadata is sufficient for the client to decide whether to download a new local version without removing the raw fallback.
- [ ] Preserve push behavior as an approval-driven visibility update rather than a new assignment model.
- [ ] Keep assigned-piece reads safe to call opportunistically from the client without requiring a separate full-library download.

### 2. Sync status surface

Extends the current `/api/v1/sync/{client_id}` router and its lightweight pending-count model. It does not introduce a server-required lock on the library.

- [ ] Keep sync-state endpoints focused on status bookkeeping that supports retry and user-facing banners.
- [ ] Add only the minimum fields needed to report meaningful sync progress and retry state to the client.
- [ ] Preserve launch-time behavior where server failure still leaves the client library usable from local storage.

## Open questions

- Alphabet rail: should drag scrubbing show an overlay letter indicator or only move the list position?
- Alphabet rail: when the dragged letter has no match in the filtered result set, should the list stay on the last valid anchor or move to the next valid anchor?
- Reader gestures: when a non-notes reader panel opens during write mode, should write mode remain active or exit automatically?
- Two-page mode: when entering write mode from a spread, which page becomes active if the user has not tapped a page first?
- Server sync: what stable remote score-version identity should the client treat as the dedupe key if multiple approved updates are published over time?
- Server sync: should the sync status endpoint remain count-based, or does the client need one durable retry token or timestamp per upload/download queue?

## Non-goals for this slice

- Replacing `LibraryScreen`, `ParentHomeScreen`, `PieceDetailScreen`, or `ReaderScreen` with new routes.
- Changing the student visibility rule or the parent intake and review information architecture.
- Turning `Recent` into an alphabetical mode.
- Adding parent annotation tools by default.
- Supporting spread-level annotation on a two-page canvas.
- Removing locally stored raw scores when approved or processed versions arrive.
- Making the server required for opening already imported or already synced scores.
- Reworking the app around a new sync architecture before the current repository and router boundaries are exercised.
