# Future UX Architecture: Unified Teacher Platform

## Vision
The goal is to transition the AZMusic parent/teacher interface away from a "developer-centric" tool and into a robust, premium student management experience. The new architecture draws inspiration from modern learning platforms (like PracticeSpace and Muzie.live), emphasizing gamification, asynchronous communication, and seamless studio administration.

## Proposed Layout & Structure (2-Level Deep Prototype)

### Level 1: Global Management
1. **Global Dashboard**
   - **Unified Newsfeed**: Aggregates all student video submissions, system alerts (e.g., "processing finished"), and teacher feedback into a single chronological stream.
   - **Leaderboard**: Ranks students based on *total time practiced* (instead of points).
   - **Global Calendar**: Displays studio-wide events and masterclasses.

2. **Students & Classes**
   - Roster view to manage all student profiles and monitor high-level activity.

3. **Repertoire Library**
   - The central repository for all global music.
   - Integrates the existing intake workflow (Import -> Processing -> Review -> Push) directly into the library interface.

### Level 2: Student Specific (e.g., Julian Rossi's Profile)
- **Student Repertoire**: Displays only the music assigned to the student's device.
- **Practice History**: Detailed stats on practice duration and streak tracking.
- **Individual Calendar**: Upcoming private lessons, goal deadlines, and video submission due dates.

## Identified Gaps to Current Codebase

To realize this vision, the following backend and frontend gaps must be addressed:

1. **Activity Feed & Messaging Engine**
   - *Current*: We store `PracticeRecording` and `RecordingRequest` but lack a unified stream.
   - *Requirement*: A new `Activity` or `Message` endpoint that interleaves videos, comments, and system alerts chronologically.

2. **Time Tracking & Gamification**
   - *Current*: We only track video submission timestamps.
   - *Requirement*: The Flutter client must measure active time spent in the sheet music viewer and sync it to a new `PracticeSession` table on the server to power the leaderboard.

3. **Calendar & Goal Management**
   - *Current*: No scheduling or long-term goal tracking exists.
   - *Requirement*: Implement `Event` and `Goal` tables on the server and corresponding UI widgets.

4. **Interactive Sheet Music Markup**
   - *Current*: The server has an `AnnotationLayer` table, but the client does not support drawing over PDFs.
   - *Requirement*: Build an interactive drawing canvas in Flutter (Draw, Highlight, Text) that serializes strokes and syncs with the backend.

5. **Flutter Routing Overhaul**
   - *Current*: Simple 3-tab layout (`Workflow`, `Students`, `Advanced`).
   - *Requirement*: Refactor routing to support a responsive sidebar layout and nested routes (e.g., `Dashboard` -> `Students` -> `Student Profile`).

## Next Steps
When we circle back to this, the recommended first steps are:
1. Refactoring the Flutter layout shell to use the new sidebar architecture.
2. Building out the `ActivityFeed` API on the Python server.
3. Wiring up the Global Repertoire Library to replace the existing intake workflow.
