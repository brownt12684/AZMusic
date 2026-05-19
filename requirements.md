# AZMusic Requirements

## Summary

AZMusic is a private family music practice system for violin-family students. The system consists of:

- A cross-platform tablet client built for `Windows Surface Book` first and `Android tablets` second
- A local home processing server running on a `Windows PC` or `NAS`
- A local-network-only workflow in v1

The core experience is:

1. Import sheet music by `PDF` or camera scan
2. Use the raw score immediately and offline
3. Process the score in the background on the home server
4. Review regenerated score and media matches
5. Approve corrected assets before they become the default student-facing version

The system is student-first in daily use, but parent-managed for review, permissions, and quality control.

## Product Goals

- Make it easy for a student to read, annotate, and practice from sheet music on a tablet
- Keep the full family library available offline on the device
- Improve imported music over time by turning raw scans or files into cleaner digital score versions
- Find and organize useful reference recordings and piano accompaniment media for each piece
- Give parents a clear review workflow before processed scores, media matches, and generated educational content become student-facing

## Scope

### In Scope for v1

- Single family account
- Per-student profiles
- Violin-family repertoire only
- Windows-first client with Android support from the same codebase
- LAN-only sync and processing
- Full offline library on client devices
- Background score processing on the home server
- Central parent review queue
- Handwritten annotation overlay
- Practice media playback
- Backend-generated `About this piece` content with approval workflow

### Out of Scope for v1

- Public app store distribution
- Multi-family tenancy
- WAN or remote-home processing
- Non-violin-family heuristics
- Full in-app notation editing
- Cloud-only backend architecture
- Public-store-compliant media integrations as a product requirement

## Primary Users

### Student

- Reads sheet music in a tablet-first interface
- Swipes between pages while practicing
- Plays approved media for reference or accompaniment
- Writes notes on top of the score
- May be allowed to review or correct content based on profile permissions

### Parent

- Imports music
- Reviews processed score candidates
- Reviews media matches
- Reviews generated `About this piece` content
- Manages profile permissions
- Uses a parent PIN for protected actions

## Client Requirements

### Platform and Stack

- The client must be a `Flutter` application
- The first target device is a `Windows Surface Book`
- The second target device is an `Android tablet`
- The app must use one shared codebase for both targets

### Library and Navigation

- The main library should organize pieces primarily by title
- Composer and instrument metadata should be visible and searchable
- The app should support per-piece detail views
- The app should keep the entire approved family library available offline by default

### Reader Experience

- The primary reading experience must center on horizontal page swiping
- Score pages should dominate the screen layout
- The reader must support toggling annotation visibility on and off
- The reader must support both stylus and finger annotation input
- An info icon must open an `About this piece` popup without forcing the user to leave the reading context

### Notes and Annotations

- Annotation layers belong to a student profile, not to the device
- Annotations should sync across that student's devices within the family account model
- The notes layer should sit visually above the score and remain optional

### Practice Media

- The client must store approved media offline
- The playback experience must support:
  - play and pause
  - scrubbing
  - playback speed control
  - loop sections
  - resume state

### Profiles and Permissions

- The app must support per-student profiles
- Profiles must allow configurable supervision levels
- Protected actions must be gated by a parent PIN on shared devices
- The supervision model must allow selected profiles to bypass parent review for some actions

## Server Requirements

### Platform and Stack

- The server must be built with `Python` and `FastAPI`
- The server must run on a home `Windows PC` or `NAS`
- The server must persist structured data in `SQLite`
- The server must use file-based storage for raw scores, processed scores, annotations exports, and media

### Connectivity

- The v1 system must operate on the local network only
- The client must sync with the server over LAN
- The architecture should not block a future WAN bridge, but v1 must not depend on it

### Background Processing

The server must support background processing jobs for:

- file ingestion
- metadata extraction
- repertoire identification
- OCR/OMR-driven score reconstruction
- generation of editable score output such as `MusicXML`
- candidate media discovery
- candidate media ranking
- educational summary generation for `About this piece`

## Core Workflows

### Music Import

1. A parent or permitted student imports a piece by `PDF` or camera scan
2. The raw import becomes readable on the client immediately
3. The client persists the raw asset for offline use
4. The client syncs the imported asset to the home server when available

### Score Processing

1. The server creates a processing job for the imported piece
2. The server extracts metadata and reconstructs a cleaner digital score candidate
3. The server returns one or more reviewable score candidates
4. The raw score remains available at all times
5. An approved processed score becomes the default reading version
6. Rejected candidates remain non-default and should not silently replace the raw version

### Media Discovery

1. The server searches broad online sources, including YouTube and other sources, using repertoire-aware queries
2. The server attempts to find:
   - a performance or reference recording
   - a separate piano accompaniment recording when available
3. Search ranking must prioritize title and composer accuracy over popularity
4. Media candidates must enter review before becoming approved offline assets

### Piece History

1. The server drafts a brief family-friendly `About this piece` summary
2. The draft must enter the review queue
3. The summary becomes visible to students only after approval
4. The client displays the approved summary in a popup/modal opened from an info icon

### Review Workflow

The review system must support:

- score candidate review
- media candidate review
- piece history review

The review queue should be centralized and parent-oriented by default.

## Review and Correction Requirements

### Review Queue

- The system must provide a central review inbox
- Review items must include concise explanations of why they need review
- Review items must expose confidence and status metadata where available

### Score Review

The client must support light score review corrections, including:

- metadata correction
- version selection
- page or region alignment review
- raw-versus-digital comparison

The client should support a raw-over-digital overlay to help validate reconstruction accuracy.

Deep notation editing is out of scope for v1. The client is not required to function as a full notation editor.

### Student Override

- Parent review is the default
- Profile settings must allow parent supervision to be relaxed for more advanced students
- A permitted student should be able to review or correct content where the profile configuration allows it

## Backend LLM Assistance

LLMs should be used only for enrichment and ambiguity resolution, not as the sole source of truth for high-impact decisions.

### Service Boundaries

The backend should define the following AI-assisted service interfaces:

#### `PieceMetadataResolver`

Purpose:

- infer normalized piece metadata from OCR text, filenames, import metadata, and partial score signals

Outputs may include:

- title
- composer
- movement or work number
- likely instrument
- collection or book
- aliases or alternate titles

#### `SearchQueryComposer`

Purpose:

- generate better search queries for recordings and accompaniment

Outputs may include:

- title variants
- abbreviations
- alternate spellings
- accompaniment-specific search phrases

#### `MediaCandidateRanker`

Purpose:

- rank discovered media candidates by likely match quality

Outputs may include:

- candidate score
- confidence value
- match explanation
- likely match category such as reference performance or accompaniment

#### `ScoreReconstructionReviewer`

Purpose:

- identify suspicious parts of the reconstructed score

Outputs may include:

- likely OCR/OMR mistakes
- alignment concerns
- probable key signature or rhythm issues
- warnings for manual review

#### `PieceHistoryDraftGenerator`

Purpose:

- generate a short readable background summary for `About this piece`

Outputs may include:

- a concise student-friendly history summary
- optional provenance marker
- generation timestamp

#### `ReviewSummaryGenerator`

Purpose:

- explain to a reviewer why an item is pending and what is uncertain

Outputs may include:

- short review-facing summary text
- detected ambiguity notes
- confidence phrasing

### LLM Usage Rules

- LLM outputs must be stored as drafts or suggestions
- LLM-assisted outputs must carry status and provenance metadata
- High-impact actions must not auto-apply solely because an LLM is confident
- Parent review is required before:
  - a processed score becomes the default version
  - a media candidate becomes an approved offline asset
  - a piece history draft becomes student-facing content

### Deterministic Responsibilities

These concerns must remain deterministic system responsibilities:

- file ingestion and storage
- sync state tracking
- job orchestration
- permission and PIN checks
- annotation persistence
- asset packaging for offline use
- rendering state and page presentation

## Data Model

The system should define at least the following entities.

### `Profile`

Purpose:

- represent a student or parent-managed student context

Minimum fields:

- `id`
- `display_name`
- `role_or_permission_mode`
- `parent_review_required`
- `created_at`
- `updated_at`

### `Piece`

Purpose:

- represent a single musical work in the family library

Minimum fields:

- `id`
- `title`
- `composer`
- `primary_instrument`
- `current_default_score_version_id`
- `library_status`
- `created_at`
- `updated_at`

### `ScoreVersion`

Purpose:

- represent a raw or processed score artifact for a piece

Minimum fields:

- `id`
- `piece_id`
- `version_type`
- `file_path_or_blob_ref`
- `status`
- `source_kind`
- `approved_at`
- `approved_by`
- `created_at`
- `updated_at`

Version types should distinguish:

- raw import
- reconstructed candidate
- approved processed version

### `AnnotationLayer`

Purpose:

- store student-specific markup on top of a score

Minimum fields:

- `id`
- `piece_id`
- `profile_id`
- `score_version_id`
- `annotation_data_ref`
- `created_at`
- `updated_at`

### `MediaAsset`

Purpose:

- represent an approved playable media item stored for offline use

Minimum fields:

- `id`
- `piece_id`
- `media_type`
- `usage_type`
- `storage_ref`
- `duration`
- `approved_at`
- `approved_by`

Usage types should support at least:

- reference performance
- piano accompaniment

### `MediaMatchCandidate`

Purpose:

- represent a discovered media candidate that is not yet approved

Minimum fields:

- `id`
- `piece_id`
- `source_name`
- `source_url_or_id`
- `usage_type`
- `candidate_status`
- `confidence`
- `explanation`
- `created_at`
- `updated_at`

### `ProcessingJob`

Purpose:

- represent background work done by the server

Minimum fields:

- `id`
- `piece_id`
- `job_type`
- `status`
- `status_message`
- `created_at`
- `updated_at`
- `completed_at`

### `ReviewItem`

Purpose:

- represent an actionable item in the review queue

Minimum fields:

- `id`
- `piece_id`
- `item_type`
- `target_id`
- `review_status`
- `summary`
- `confidence`
- `created_at`
- `updated_at`
- `reviewed_at`
- `reviewed_by`

Item types must support:

- `score_candidate`
- `media_candidate`
- `piece_history`

### `PieceHistoryDraft`

Purpose:

- represent generated educational content for a piece

Minimum fields:

- `id`
- `piece_id`
- `summary_text`
- `generation_status`
- `review_status`
- `provenance_note`
- `approved_at`
- `approved_by`
- `created_at`
- `updated_at`

### `SyncState`

Purpose:

- represent client-server sync state for offline-first operation

Minimum fields:

- `id`
- `entity_type`
- `entity_id`
- `sync_status`
- `last_synced_at`
- `sync_error`

## API Expectations

The server API should expose clear request and response models for at least:

- upload or import a score
- list pieces
- fetch piece details
- fetch score versions for a piece
- fetch approved media for a piece
- fetch approved piece history for a piece
- fetch review queue items
- approve or reject a review item
- update light score review corrections
- fetch processing job status
- sync changed data to the client

The API should remain versionable and explicit.

## Storage and Offline Requirements

- The client must be able to read previously synced pieces without server access
- The client must store approved scores, annotations, metadata, and media offline
- Raw imports must remain locally accessible even before processing finishes
- Sync failure should not block local reading of already-available content

## Acceptance Criteria

The v1 system should satisfy the following scenarios:

1. A user imports a PDF and can read it offline immediately.
2. A user captures a scan and can read the raw result before processing completes.
3. The server creates a processing job and returns a reviewable digital score candidate.
4. A parent approves a corrected score candidate and it becomes the default reading version.
5. The raw version remains accessible after a processed version is approved.
6. The server finds both a reference recording and a piano accompaniment candidate for a known violin-family piece when such media exists.
7. Approved media becomes available offline on the client.
8. A student writes annotations on a piece and can toggle the notes layer on and off.
9. Parent PIN blocks protected actions for restricted profiles.
10. A permitted advanced student can bypass selected review restrictions based on profile settings.
11. The server generates a draft `About this piece` summary that enters review.
12. An approved `About this piece` summary is shown from an info icon as a popup/modal in the app.
13. The client continues to provide access to already-synced content when the home server is offline.

## Implementation Defaults

Unless changed later, the implementation should assume:

- `Flutter` client
- `Riverpod` for state management
- `drift` over `SQLite` on the client
- `FastAPI` and `SQLite` on the server
- LAN HTTPS communication between client and server
- file-based storage for large assets
- adapter-based integration points for OCR/OMR, media discovery, media ingestion, and LLM enrichment

## Notes for Future Versions

- Add WAN connectivity back to the home server
- Expand heuristics and metadata handling beyond violin-family repertoire
- Add deeper notation editing workflows
- Consider richer source provenance and citation support for educational content
