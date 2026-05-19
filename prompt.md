# AZMusic Bootstrap Prompt

Use the following prompt with a coding agent to start the project from scratch.

```text
You are building a greenfield private family music practice system in a monorepo. The system has two main parts:

1. A Flutter client app targeting Windows Surface Book first and Android tablets second.
2. A Python FastAPI home-server service for LAN-only processing in v1.

This is a private/sideloaded system, not a public Play Store product. Optimize for real functionality, maintainability, and modular architecture rather than store-review constraints.

Primary product goal:
Help a family manage violin-family sheet music for a student. The user must be able to import PDF files and camera scans, use the raw score immediately and offline, then send the score to a local home server for background indexing and digital reconstruction into an editable score format such as MusicXML. The processed version should only replace the raw version in the main reading view after approval. The raw version must always remain available as fallback.

Build this in phases. Do not skip architecture. Scaffold first, then shared domain model, then persistence/sync, then UI shells, then provider stubs, then tests.

================================
PRODUCT REQUIREMENTS
================================

Audience and scope:
- Single family account in v1
- Student-first tablet experience
- Parent-managed permissions and review
- Violin-family repertoire only in v1
- LAN-only operation in v1
- Full offline library on each client device by default

Client requirements:
- Flutter app with one shared codebase for Windows first and Android second
- Main reader centered on horizontal swipe navigation between score pages
- Toggleable handwritten notes overlay on top of sheet music
- Stylus and finger input support
- Per-student annotation layers
- Parent PIN for protected actions on shared devices
- Central review queue UI
- Piece detail or reader info icon that opens an “About this piece” popup/modal
- Practice playback controls for approved media:
  - play/pause
  - scrubbing
  - speed control
  - loop sections
  - resume state

Music import and processing workflow:
- Import by PDF file or camera scan
- Make the raw import available immediately for offline reading
- Sync imported material to the FastAPI server over LAN
- Server performs background processing to:
  - extract and normalize metadata
  - identify repertoire
  - reconstruct a digital editable score candidate
  - discover candidate performance/reference recordings
  - discover candidate piano accompaniment recordings
  - draft a brief “About this piece” summary/history
- Search ranking should prioritize title/composer accuracy over popularity
- New score/media/history candidates enter a central review queue
- Parent can approve/reject candidates and make light corrections
- Review UI should support raw-over-digital comparison overlay
- Do not implement deep in-app notation editing in v1
- Processed score becomes default only after approval
- Approved “About this piece” content becomes visible in the app only after approval
- Raw score remains accessible at all times

Permissions/supervision:
- Single family account in v1
- Per-student profiles
- Profiles can be parent-managed or more independent
- Use a simple local parent PIN for protected actions
- Some student profiles may bypass selected supervision gates

Backend AI/LLM requirements:
Use LLMs only as enrichment and ambiguity-resolution components, not as the source of truth for high-impact actions.

Add service interfaces for:
- PieceMetadataResolver
- SearchQueryComposer
- MediaCandidateRanker
- ScoreReconstructionReviewer
- PieceHistoryDraftGenerator
- ReviewSummaryGenerator

Rules for AI-assisted outputs:
- Treat LLM outputs as drafts/suggestions
- Persist confidence, timestamps, and provenance markers
- Do not auto-approve high-impact outputs
- Require review before:
  - processed score becomes default
  - media candidate becomes approved
  - piece history becomes visible to the student

Keep these deterministic:
- file ingestion and storage
- sync state
- job orchestration
- permissions/PIN checks
- annotation persistence
- offline packaging
- local rendering state

================================
TECHNICAL STACK
================================

Use these defaults unless there is a strong implementation reason not to:
- Flutter client
- Riverpod for state management
- Drift + SQLite for client persistence
- Python FastAPI backend
- SQLite on server
- File-based blob storage for scores, scans, annotations exports, and media
- Clear service/repository boundaries
- Adapter interfaces for OCR/OMR, media search, media ingestion, and LLM-backed enrichment
- HTTPS over LAN between client and server
- Windows packaging first, Android packaging second

================================
ARCHITECTURE REQUIREMENTS
================================

Create a monorepo with clean separation between:
- client app
- server app
- shared documentation
- optional shared schemas/contracts if useful

Define domain entities early. At minimum include:
- Profile
- Piece
- ScoreVersion
- AnnotationLayer
- MediaAsset
- MediaMatchCandidate
- ProcessingJob
- ReviewItem
- PieceHistoryDraft
- SyncState

For each entity define:
- purpose
- identifiers
- ownership relationships
- lifecycle status
- created/updated timestamps where appropriate

Suggested status examples:
- Piece: imported, processing, review_pending, approved, archived
- ScoreVersion: raw, reconstructed_candidate, approved, rejected
- MediaMatchCandidate: discovered, review_pending, approved, rejected
- PieceHistoryDraft: generated, review_pending, approved, rejected
- ProcessingJob: queued, running, succeeded, failed

Model the distinction between:
- raw source artifacts
- processed candidate artifacts
- approved artifacts visible in primary UX

================================
PHASED EXECUTION PLAN
================================

Phase 1: Repository scaffold
- Create monorepo structure
- Add top-level README with architecture overview and run instructions
- Add separate client and server project setup
- Add basic lint/test tooling for both sides
- Add environment/config templates
- Add placeholder docs folder for architecture and API notes

Phase 2: Shared domain and persistence design
- Define domain model and persistence schema for client and server
- Set up Flutter local database with Drift
- Set up FastAPI server SQLite schema and repositories
- Keep schemas simple but extensible
- Implement migrations or migration-ready structure if practical

Phase 3: Server foundation
- Build FastAPI app structure with routers, services, repositories, and job orchestration
- Add LAN-auth/config placeholders appropriate for a private local server
- Implement endpoints for:
  - piece import/upload
  - list pieces
  - fetch piece details
  - fetch score versions
  - fetch review queue
  - approve/reject review items
  - fetch approved history for a piece
  - sync job/status polling
- Add file storage abstraction
- Add background job pipeline skeleton

Phase 4: AI/provider abstraction layer
- Add interface boundaries and stub/mock implementations for:
  - OCR/OMR provider
  - metadata resolver
  - search query generator
  - media search provider
  - media candidate ranker
  - score reconstruction reviewer
  - piece history generator
  - review summary generator
- Do not wire to real third-party services yet unless needed for a minimal demo path
- Keep implementations swappable and testable

Phase 5: Client foundation
- Build app shell with navigation and core state wiring
- Build library screen
- Build piece detail screen
- Build reader shell with horizontal paging
- Build toggleable annotation layer shell
- Build review queue screen
- Build About-this-piece popup/modal
- Build profile selection/settings shell with parent PIN gating hooks

Phase 6: Offline-first and sync
- Implement local-first data flow on the client
- Support immediate local import of PDFs/scans before server processing completes
- Add sync manager for LAN communication with the server
- Persist sync state locally
- Handle offline/no-server state gracefully
- Keep library and approved assets available without active server access

Phase 7: Review workflows
- Implement central review queue
- Support review item types for:
  - score candidate
  - media candidate
  - piece history
- Add approve/reject actions
- Add light correction hooks:
  - metadata correction
  - version selection
  - alignment/overlay review support
- Keep deep notation editing out of scope

Phase 8: Media and playback shell
- Add approved media asset model and local storage handling
- Add playback UI shell with:
  - play/pause
  - scrub
  - speed control
  - loop support
  - resume state
- Keep the media ingestion pipeline abstract enough to support later source changes

Phase 9: Tests and validation
- Add tests for core domain and workflows
- Validate import, review, approval, offline reading, and permission flows
- Ensure the codebase is runnable with mocked processing/search providers

================================
UX AND UI DIRECTION
================================

Design for tablet use, not phone-first UI stretched upward.
Prioritize:
- readable sheet music
- fast page navigation
- clean practice-oriented layout
- obvious separation between student actions and parent-only actions
- low-friction review flows
- pen-friendly targets on Windows tablets

Reader priorities:
- score consumes most of the screen
- page swipe should feel primary
- notes layer must be visually distinct but unobtrusive
- info icon should open “About this piece” as a popup without disrupting reading context

Review priorities:
- parents need clear reasons why an item is pending review
- raw-versus-digital comparison should be supported structurally
- history draft should be short, readable, and clearly marked as approved content once approved

================================
DATA AND API EXPECTATIONS
================================

Expose a clean server API surface. Include request/response models and document them in code.

Minimum API capabilities:
- upload/import a score
- list pieces
- get piece details
- get available score versions
- get approved media assets
- get approved piece history
- list review items
- approve/reject a review item
- update light review corrections
- get processing job status
- sync changed data to client

Keep API shapes explicit and versionable.

================================
NON-GOALS
================================

Do not optimize for these in v1:
- public app store release
- multi-family tenancy
- WAN/remote-home sync
- non-violin-family repertoire heuristics
- full notation editor in the client
- production-grade third-party provider integrations before architecture is stable
- cloud-only backend assumptions

================================
QUALITY BAR
================================

The code should be structured so another engineer can continue it without re-architecting.
Prefer modularity and clear boundaries over clever shortcuts.
Do not leave everything as TODOs; implement real vertical slices where possible, even if provider integrations are mocked.

At the end, provide:
1. Monorepo structure summary
2. Key architectural decisions
3. What is implemented versus stubbed
4. How to run client and server locally
5. Recommended next steps for real provider integration
```
