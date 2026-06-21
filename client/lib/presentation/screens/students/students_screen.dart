import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/profile.dart';
import '../../providers/activity_providers.dart';
import '../../providers/piece_providers.dart';
import '../../providers/profile_providers.dart';
import '../parent/parent_home_screen.dart';

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> with SingleTickerProviderStateMixin {
  String? _selectedStudentId;
  String _searchQuery = '';
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentProfilesProvider);
    
    // Find selected student
    Profile? selectedStudent;
    if (_selectedStudentId != null) {
      try {
        selectedStudent = students.firstWhere((s) => s.id == _selectedStudentId);
      } catch (_) {
        selectedStudent = null;
      }
    }

    if (selectedStudent != null) {
      return _buildProfileView(selectedStudent);
    } else {
      return _buildRosterView(students);
    }
  }

  // ─── ROSTER VIEW (Level 1) ──────────────────────────────────────────────────

  Widget _buildRosterView(List<Profile> students) {
    final filteredStudents = students.where((s) {
      return s.displayName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final piecesAsync = ref.watch(allPiecesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Students & Classes',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddStudentDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Student'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search for a student...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Roster List
            Expanded(
              child: filteredStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty ? 'No students yet' : 'No students matching search',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          if (_searchQuery.isEmpty)
                            TextButton(
                              onPressed: () => _showAddStudentDialog(context),
                              child: const Text('Add your first student profile'),
                            ),
                        ],
                      ),
                    )
                  : piecesAsync.when(
                      data: (entries) => ListView.builder(
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          
                          // Find active pieces for this student
                          final studentPieces = entries.where((e) {
                            return e.piece.visibleToProfileIds.contains(student.id) ||
                                   e.piece.assignedProfileId == student.id;
                          }).toList();

                          final activePieceTitle = studentPieces.isNotEmpty
                              ? studentPieces.first.piece.title
                              : 'No assigned pieces';

                          return _buildStudentCard(student, activePieceTitle);
                        },
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Center(child: Text('Error loading library: $e')),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Profile student, String activePieceTitle) {
    final avatarColors = _getAvatarColor(student.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _selectedStudentId = student.id;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Row(
            children: [
              // Initials Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: avatarColors.bgColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _getInitials(student.displayName),
                  style: TextStyle(
                    color: avatarColors.textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Student Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activePieceTitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Stats or Meta Info
              Row(
                children: [
                  _buildRosterMetaItem(
                    label: 'Instrument',
                    value: _instrumentLabel(student.instrument),
                  ),
                  const SizedBox(width: 32),
                  // Practice stats provider link
                  Consumer(
                    builder: (context, ref, child) {
                      final sessionsAsync = ref.watch(practiceSessionsProvider(student.id));
                      return sessionsAsync.when(
                        data: (sessions) {
                          final totalSeconds = sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
                          final hours = totalSeconds / 3600;
                          return _buildRosterMetaItem(
                            label: 'Practiced',
                            value: hours > 0 ? '${hours.toStringAsFixed(1)}h' : '0h',
                          );
                        },
                        loading: () => _buildRosterMetaItem(label: 'Practiced', value: '...'),
                        error: (_, __) => _buildRosterMetaItem(label: 'Practiced', value: 'Error'),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.qr_code_2_outlined),
                tooltip: 'Pair/Resync Device QR Code',
                onPressed: () => showStudentPairingDialog(context, ref, student),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRosterMetaItem({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  // ─── PROFILE VIEW (Level 2) ─────────────────────────────────────────────────

  Widget _buildProfileView(Profile student) {
    final avatarColors = _getAvatarColor(student.id);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _selectedStudentId = null;
            });
          },
        ),
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedStudentId = null;
                });
              },
              child: Text(
                'Students',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('/', style: TextStyle(color: Colors.grey)),
            ),
            Text(
              student.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_outlined),
            tooltip: 'Resync Device (QR Code)',
            onPressed: () => showStudentPairingDialog(context, ref, student),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Student Details',
            onPressed: () => _showEditStudentDialog(context, student),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton.icon(
              onPressed: () => _confirmDeleteStudent(context, student),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Hero Profile Banner Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: avatarColors.bgColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _getInitials(student.displayName),
                        style: TextStyle(
                          color: avatarColors.textColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.displayName,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Instrument: ${_instrumentLabel(student.instrument)}  •  Role: Student',
                            style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action Buttons Panel
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => showStudentPairingDialog(context, ref, student),
                          icon: const Icon(Icons.qr_code_2_outlined),
                          label: const Text('Resync Device'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _showLogPracticeDialog(context, student.id),
                          icon: const Icon(Icons.play_circle_fill_outlined),
                          label: const Text('Log Practice'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showAssignPieceDialog(context, student),
                          icon: const Icon(Icons.library_music),
                          label: const Text('Assign Piece'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Multi-Pane Content Layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left 2/3 Column: Repertoire, Goals, Sessions
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TabBar(
                            controller: _tabController,
                            tabs: const [
                              Tab(text: 'Repertoire'),
                              Tab(text: 'Goals'),
                              Tab(text: 'Practice History'),
                            ],
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 450,
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildRepertoireTab(student),
                                _buildGoalsTab(student.id),
                                _buildPracticeTab(student.id),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Right 1/3 Column: Calendar Events & Activity Feed
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildCalendarWidget(student.id),
                      const SizedBox(height: 24),
                      _buildActivityWidget(student.id),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── TABS ──────────────────────────────────────────────────────────────────

  Widget _buildRepertoireTab(Profile student) {
    final piecesAsync = ref.watch(allPiecesProvider);

    return piecesAsync.when(
      data: (entries) {
        final assigned = entries.where((entry) {
          return entry.piece.visibleToProfileIds.contains(student.id) ||
                 entry.piece.assignedProfileId == student.id;
        }).toList();

        if (assigned.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.library_music_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text('No pieces assigned to this student yet.'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _showAssignPieceDialog(context, student),
                  child: const Text('Assign Piece'),
                )
              ],
            ),
          );
        }

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6,
          ),
          itemCount: assigned.length,
          itemBuilder: (context, index) {
            final entry = assigned[index];
            return Card(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        entry.piece.libraryStatus.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      entry.piece.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.piece.composer ?? 'Unknown Composer',
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error loading repertoire: $e')),
    );
  }

  Widget _buildGoalsTab(String studentId) {
    final goalsAsync = ref.watch(goalsProvider(studentId));

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Assignments & Goals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(
              onPressed: () => _showAddGoalDialog(context, studentId),
              icon: const Icon(Icons.add),
              label: const Text('Add Goal'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: goalsAsync.when(
            data: (goals) {
              if (goals.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flag_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      const Text('No goals set for this student yet.'),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: goals.length,
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  return CheckboxListTile(
                    title: Text(
                      goal.title,
                      style: TextStyle(
                        decoration: goal.isCompleted ? TextDecoration.lineThrough : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      goal.dueDate != null 
                          ? 'Due ${DateFormat.yMMMd().format(goal.dueDate!)}'
                          : 'No due date',
                    ),
                    value: goal.isCompleted,
                    onChanged: (val) async {
                      try {
                        await ref.read(activityRepositoryProvider).toggleGoal(goal.id);
                        ref.invalidate(goalsProvider(studentId));
                        ref.invalidate(activityFeedProvider(studentId));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update goal: $e')),
                        );
                      }
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error loading goals: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildPracticeTab(String studentId) {
    final sessionsAsync = ref.watch(practiceSessionsProvider(studentId));

    return sessionsAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text('No practice history logged yet.'),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            final minutes = session.durationSeconds ~/ 60;
            return ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.music_note),
              ),
              title: Text(
                'Practiced for $minutes minutes',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(DateFormat.yMMMd().add_jm().format(session.sessionDate)),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error loading practice sessions: $e')),
    );
  }

  // ─── RIGHT WIDGETS ──────────────────────────────────────────────────────────

  Widget _buildCalendarWidget(String studentId) {
    final eventsAsync = ref.watch(studioEventsProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upcoming Events',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                TextButton(
                  onPressed: () => _showAddEventDialog(context, studentId),
                  child: const Text('+ Event'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            eventsAsync.when(
              data: (events) {
                final studentEvents = events.where((e) => e.studentProfileId == studentId).toList();
                if (studentEvents.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Text('No upcoming lessons or events.'),
                    ),
                  );
                }

                return Column(
                  children: studentEvents.map((evt) {
                    final day = DateFormat.d().format(evt.startTime);
                    final month = DateFormat.MMM().format(evt.startTime);
                    final time = DateFormat.jm().format(evt.startTime);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            width: 48,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  month.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  day,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  evt.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  time,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error loading events: $e')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityWidget(String studentId) {
    final activityAsync = ref.watch(activityFeedProvider(studentId));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity Feed',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            activityAsync.when(
              data: (feed) {
                if (feed.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Text('No recent activity for this student.'),
                    ),
                  );
                }

                return Column(
                  children: feed.take(5).map((event) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                event.eventType == 'submission' 
                                    ? Icons.play_circle_outline 
                                    : Icons.info_outline,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                event.eventType.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                DateFormat.yMMMd().add_jm().format(event.createdAt),
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.content,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const Divider(),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error loading activity: $e')),
            ),
          ],
        ),
      ),
    );
  }

  // ─── DIALOGS & ACTIONS ──────────────────────────────────────────────────────

  void _showAddStudentDialog(BuildContext context) {
    final nameController = TextEditingController();
    InstrumentType selectedInstrument = InstrumentType.violin;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Student Profile'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'e.g. Emma Watson',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<InstrumentType>(
                    value: selectedInstrument,
                    decoration: const InputDecoration(
                      labelText: 'Instrument',
                    ),
                    items: InstrumentType.values.map((inst) {
                      return DropdownMenuItem(
                        value: inst,
                        child: Text(_instrumentLabel(inst)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedInstrument = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a student name')),
                      );
                      return;
                    }
                    try {
                      final newStudent = await ref.read(localStudentProfilesProvider.notifier).addStudent(
                        displayName: name,
                        instrument: selectedInstrument,
                      );
                      ref.invalidate(studentProfilesProvider);
                      
                      try {
                        await ref.read(activityRepositoryProvider).createActivityEvent(
                          eventType: 'system_alert',
                          targetProfileId: newStudent.id,
                          content: 'Registered a new student profile: $name (${_instrumentLabel(selectedInstrument)})',
                        );
                      } catch (_) {}

                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error adding student: $e')),
                      );
                    }
                  },
                  child: const Text('Create Profile'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditStudentDialog(BuildContext context, Profile student) {
    final nameController = TextEditingController(text: student.displayName);
    InstrumentType selectedInstrument = student.instrument;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Student Profile'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<InstrumentType>(
                    value: selectedInstrument,
                    decoration: const InputDecoration(
                      labelText: 'Instrument',
                    ),
                    items: InstrumentType.values.map((inst) {
                      return DropdownMenuItem(
                        value: inst,
                        child: Text(_instrumentLabel(inst)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedInstrument = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    try {
                      await ref.read(localStudentProfilesProvider.notifier).editStudent(
                        id: student.id,
                        displayName: name,
                        instrument: selectedInstrument,
                      );
                      ref.invalidate(studentProfilesProvider);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error editing student: $e')),
                      );
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteStudent(BuildContext context, Profile student) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Remove ${student.displayName}?'),
          content: const Text(
            'Are you sure you want to remove this student profile? This will not delete their recordings but will unassign pieces and hide them from the roster.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                try {
                  await ref.read(localStudentProfilesProvider.notifier).removeStudent(student.id);
                  ref.invalidate(studentProfilesProvider);
                  setState(() {
                    _selectedStudentId = null;
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error removing student: $e')),
                  );
                }
              },
              child: const Text('Remove Student', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAssignPieceDialog(BuildContext context, Profile student) {
    final piecesAsync = ref.watch(allPiecesProvider);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Assign Piece to Student'),
          content: SizedBox(
            width: 400,
            height: 300,
            child: piecesAsync.when(
              data: (entries) {
                final unassigned = entries.where((entry) {
                  return !entry.piece.visibleToProfileIds.contains(student.id) &&
                         entry.piece.assignedProfileId != student.id;
                }).toList();

                if (unassigned.isEmpty) {
                  return const Center(
                    child: Text('All library pieces are already assigned to this student.'),
                  );
                }

                return ListView.builder(
                  itemCount: unassigned.length,
                  itemBuilder: (context, index) {
                    final entry = unassigned[index];
                    return ListTile(
                      title: Text(entry.piece.title),
                      subtitle: Text(entry.piece.composer ?? 'Unknown Composer'),
                      trailing: const Icon(Icons.add),
                      onTap: () async {
                        try {
                          await ref.read(allPiecesProvider.notifier).pushToProfiles(
                            pieceId: entry.piece.id,
                            profileIds: [student.id],
                          );
                          ref.invalidate(allPiecesProvider);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Assigned "${entry.piece.title}" to ${student.displayName}')),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to assign piece: $e')),
                          );
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showAddGoalDialog(BuildContext context, String studentId) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Learning Goal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Goal Title',
                      hintText: 'e.g. Master Vivaldi measures 24-36',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedDate == null 
                            ? 'No due date selected'
                            : 'Due Date: ${DateFormat.yMMMd().format(selectedDate!)}',
                      ),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setDialogState(() {
                              selectedDate = date;
                            });
                          }
                        },
                        child: const Text('Select Date'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    try {
                      await ref.read(activityRepositoryProvider).createGoal(
                        studentId,
                        title: title,
                        description: descController.text.trim(),
                        dueDate: selectedDate,
                      );
                      ref.invalidate(goalsProvider(studentId));
                      ref.invalidate(activityFeedProvider(studentId));
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to add goal: $e')),
                      );
                    }
                  },
                  child: const Text('Add Goal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddEventDialog(BuildContext context, String studentId) {
    final titleController = TextEditingController(text: 'Private Lesson');
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 15, minute: 30);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Calendar Event'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Event Title',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Date: ${DateFormat.yMMMd().format(selectedDate)}'),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setDialogState(() {
                              selectedDate = date;
                            });
                          }
                        },
                        child: const Text('Select Date'),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Time: ${selectedTime.format(context)}'),
                      TextButton(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (time != null) {
                            setDialogState(() {
                              selectedTime = time;
                            });
                          }
                        },
                        child: const Text('Select Time'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    
                    final startDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                    final endDateTime = startDateTime.add(const Duration(minutes: 45));

                    try {
                      await ref.read(activityRepositoryProvider).createEvent(
                        title: title,
                        description: descController.text.trim(),
                        startTime: startDateTime,
                        endTime: endDateTime,
                        studentProfileId: studentId,
                      );
                      ref.invalidate(studioEventsProvider);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to add calendar event: $e')),
                      );
                    }
                  },
                  child: const Text('Save Event'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogPracticeDialog(BuildContext context, String studentId) {
    final durationController = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log Practice Session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter practice duration in minutes:'),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (minutes)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final mins = int.tryParse(durationController.text) ?? 0;
                if (mins <= 0) return;
                try {
                  await ref.read(activityRepositoryProvider).createPracticeSession(
                    studentId,
                    durationSeconds: mins * 60,
                    sessionDate: DateTime.now(),
                  );
                  ref.invalidate(practiceSessionsProvider(studentId));
                  ref.invalidate(activityFeedProvider(studentId));
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to log practice session: $e')),
                  );
                }
              },
              child: const Text('Log Session'),
            ),
          ],
        );
      },
    );
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────────

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  _AvatarColors _getAvatarColor(String id) {
    final int hash = id.hashCode;
    final int index = hash.abs() % 4;

    switch (index) {
      case 0: // Gold
        return const _AvatarColors(bgColor: Color(0xFFFEF3C7), textColor: Color(0xFFD97706));
      case 1: // Emerald
        return const _AvatarColors(bgColor: Color(0xFFD1FAE5), textColor: Color(0xFF059669));
      case 2: // Indigo
        return const _AvatarColors(bgColor: Color(0xFFE0E7FF), textColor: Color(0xFF4338CA));
      default: // Cyan
        return const _AvatarColors(bgColor: Color(0xFFE0F2FE), textColor: Color(0xFF0369A1));
    }
  }

  String _instrumentLabel(InstrumentType instrument) {
    switch (instrument) {
      case InstrumentType.violin:
        return 'Violin';
      case InstrumentType.viola:
        return 'Viola';
      case InstrumentType.cello:
        return 'Cello';
      case InstrumentType.doubleBass:
        return 'Double bass';
      case InstrumentType.guitar:
        return 'Guitar';
      case InstrumentType.piano:
        return 'Piano';
      case InstrumentType.other:
        return 'Other';
    }
  }
}

class _AvatarColors {
  final Color bgColor;
  final Color textColor;
  const _AvatarColors({required this.bgColor, required this.textColor});
}
