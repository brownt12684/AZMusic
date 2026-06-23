import 'dart:io';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../app/routes/app_router.dart';
import '../../../../app/app_keys.dart';
import '../../../../core/import/score_import_picker.dart';
import '../../../../domain/entities/library_entry.dart';
import '../../../../domain/entities/piece.dart';
import '../../../../domain/entities/profile.dart';
import '../../../../domain/entities/score_version.dart';
import '../../../../domain/entities/review_candidate_package.dart';
import '../../../../domain/entities/processing_settings.dart';
import '../../providers/piece_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/review_providers.dart';
import '../../providers/processing_settings_providers.dart';
import '../parent/parent_home_screen.dart';

class _InstrumentTab {
  final InstrumentType? type;
  final String label;
  const _InstrumentTab(this.type, this.label);
}

const List<_InstrumentTab> _instrumentTabs = [
  _InstrumentTab(InstrumentType.violin, 'Violin'),
  _InstrumentTab(InstrumentType.viola, 'Viola'),
  _InstrumentTab(InstrumentType.cello, 'Cello'),
  _InstrumentTab(InstrumentType.doubleBass, 'Double Bass'),
  _InstrumentTab(InstrumentType.guitar, 'Guitar'),
  _InstrumentTab(InstrumentType.piano, 'Piano'),
  _InstrumentTab(null, 'Other'),
];

String _instrumentLabel(InstrumentType instrument) {
  switch (instrument) {
    case InstrumentType.violin:
      return 'Violin';
    case InstrumentType.viola:
      return 'Viola';
    case InstrumentType.cello:
      return 'Cello';
    case InstrumentType.doubleBass:
      return 'Double Bass';
    case InstrumentType.guitar:
      return 'Guitar';
    case InstrumentType.piano:
      return 'Piano';
    case InstrumentType.other:
      return 'Other';
  }
}

class GlobalLibraryScreen extends ConsumerStatefulWidget {
  const GlobalLibraryScreen({super.key});

  @override
  ConsumerState<GlobalLibraryScreen> createState() => _GlobalLibraryScreenState();
}

class _GlobalLibraryScreenState extends ConsumerState<GlobalLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final piecesAsync = ref.watch(allPiecesProvider);
    final students = ref.watch(studentProfilesProvider);
    final reviewQueueAsync = ref.watch(parentReviewQueueProvider);
    final processingCapabilitiesAsync = ref.watch(processingCapabilitiesProvider);

    return DefaultTabController(
      length: _instrumentTabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Repertoire Library',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabs: _instrumentTabs.map((tab) => Tab(text: tab.label)).toList(),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ElevatedButton.icon(
                key: AppKeys.parentImportButton,
                onPressed: () => _importPiece(context),
                icon: const Icon(Icons.upload_file),
                label: const Text('Import'),
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
        body: piecesAsync.when(
          data: (entries) {
            final reviewQueue = reviewQueueAsync.valueOrNull ?? [];

            return TabBarView(
              children: _instrumentTabs.map((tab) {
                // Filter entries for this tab
                final tabEntries = entries.where((e) {
                  final pieceInst = e.piece.primaryInstrument?.toLowerCase();
                  if (tab.type == null) {
                    if (pieceInst == null || pieceInst.isEmpty || pieceInst == 'other') return true;
                    final isStandard = InstrumentType.values
                        .take(6)
                        .any((t) => t.name.toLowerCase() == pieceInst);
                    return !isStandard;
                  } else {
                    return pieceInst == tab.type!.name.toLowerCase();
                  }
                }).toList();

                final filteredEntries = tabEntries.where((e) {
                  final titleMatch = e.piece.title.toLowerCase().contains(_searchQuery.toLowerCase());
                  final composerMatch = (e.piece.composer ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
                  return titleMatch || composerMatch;
                }).toList();

                return SingleChildScrollView(
                  key: AppKeys.parentWorkflowList,
                  child: Column(
                    children: [
                      // 1. Intake & Processing Pipeline
                      _buildPipelineSection(context, tabEntries, students, reviewQueue, processingCapabilitiesAsync),
                      
                      const Divider(height: 1, thickness: 1),
                      
                      // 2. Global Library Header & Grid
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Global ${tab.label} Collection',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  constraints: const BoxConstraints(maxWidth: 300),
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (val) {
                                      setState(() {
                                        _searchQuery = val;
                                      });
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Search by title or composer...',
                                      prefixIcon: const Icon(Icons.search, size: 18),
                                      isDense: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Theme.of(context).colorScheme.outlineVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Grid of ready pieces
                            _buildLibraryGrid(context, filteredEntries, students),
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
          error: (e, s) => Center(child: Text('Error loading library: $e')),
        ),
      ),
    );
  }

  // ─── PIPELINE SECTION ──────────────────────────────────────────────────────

  Widget _buildPipelineSection(
    BuildContext context, 
    List<LibraryEntry> entries, 
    List<Profile> students, 
    List<ReviewQueueEntry> reviewQueue,
    AsyncValue<ProcessingCapabilities> processingCapabilitiesAsync,
  ) {
    // Categorize entries
    final uploading = entries.where((e) => e.piece.libraryStatus == LibraryStatus.uploadPending).toList();
    final processing = entries.where((e) => e.piece.libraryStatus == LibraryStatus.processing).toList();
    final needsReview = entries.where((e) => 
      e.piece.libraryStatus == LibraryStatus.review || 
      e.piece.libraryStatus == LibraryStatus.intake
    ).toList();
    final readyToPush = entries.where((e) => 
      e.piece.libraryStatus == LibraryStatus.needsEdits ||
      (e.piece.libraryStatus == LibraryStatus.ready && e.piece.visibleToProfileIds.isEmpty)
    ).toList();

    return Container(
      key: AppKeys.parentReviewCard,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Intake & Processing Workflow',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Monitor the status of newly imported sheet music.',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          processingCapabilitiesAsync.when(
            data: (capabilities) => capabilities.jobSummary.activeJobs.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: ProcessingTrackerCard(summary: capabilities.jobSummary),
                  ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ProcessingTrackerErrorCard(error: error),
            ),
            loading: () => const Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ProcessingTrackerLoadingCard(),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildPipelineCard(context, '1. Uploading', uploading, Colors.blue, null, students)),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPipelineCard(
                  context, 
                  '2. Processing', 
                  processing, 
                  Theme.of(context).colorScheme.primary, 
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)), 
                  students,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPipelineCard(
                  context, 
                  '3. Needs Review', 
                  needsReview, 
                  Colors.amber[700]!, 
                  null, 
                  students,
                  actionBuilder: (entry) {
                    final reviewItem = reviewQueue.firstWhereOrNull(
                      (ReviewQueueEntry item) => item.pieceId == entry.piece.serverPieceId || item.pieceId == entry.piece.id,
                    );
                    return TextButton(
                      onPressed: () {
                        if (reviewItem != null) {
                          Navigator.pushNamed(
                            context,
                            AppRouter.reviewCompare,
                            arguments: reviewItem.id,
                          );
                        } else {
                          _showReviewDialog(context, entry);
                        }
                      },
                      child: const Text('Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPipelineCard(
                  context, 
                  '4. Ready to Push', 
                  readyToPush, 
                  Colors.green[700]!, 
                  null, 
                  students,
                  actionBuilder: (entry) => TextButton(
                    onPressed: () => _showPieceDetailsDialog(context, entry, students, initialTabIndex: 1),
                    child: const Text('Push', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineCard(
    BuildContext context, 
    String title, 
    List<LibraryEntry> entries, 
    Color themeColor,
    Widget? trailingWidget,
    List<Profile> students, {
    Widget Function(LibraryEntry)? actionBuilder,
  }) {
    final hasItems = entries.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasItems ? themeColor.withOpacity(0.5) : Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
          width: hasItems ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minHeight: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: hasItems ? themeColor : Colors.grey,
                ),
              ),
              if (hasItems && trailingWidget != null) trailingWidget,
            ],
          ),
          const SizedBox(height: 12),
          if (!hasItems)
            Text(
              'Queue is empty.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            )
          else
            Column(
              children: entries.take(3).map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.piece.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (actionBuilder != null) actionBuilder(entry),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ─── GLOBAL LIBRARY GRID ──────────────────────────────────────────────────

  Widget _buildLibraryGrid(BuildContext context, List<LibraryEntry> entries, List<Profile> students) {
    // Only display ready pieces in the main collection grid
    final readyPieces = entries.where((e) => e.piece.libraryStatus == LibraryStatus.ready).toList();

    if (readyPieces.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_music_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('No pieces in the library collection yet.'),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: readyPieces.length,
      itemBuilder: (context, index) {
        final entry = readyPieces[index];
        final pushedCount = entry.piece.visibleToProfileIds.length;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showPieceDetailsDialog(context, entry, students, initialTabIndex: 0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
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
                  const Spacer(),
                  const Divider(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${entry.scoreVersions.length} versions',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        pushedCount > 0 ? 'Pushed to $pushedCount' : 'Global only',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: pushedCount > 0 ? Theme.of(context).colorScheme.primary : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── DIALOGS & IMPORT ──────────────────────────────────────────────────────

  void _showPieceDetailsDialog(
    BuildContext context, 
    LibraryEntry entry, 
    List<Profile> students, {
    int initialTabIndex = 0,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return _PieceDetailsDialog(
          entry: entry,
          students: students,
          initialTabIndex: initialTabIndex,
        );
      },
    );
  }

  Future<void> _importPiece(BuildContext context) async {
    final picker = ref.read(scoreImportPickerProvider);
    final sourcePath = await picker.pickScorePath();
    if (sourcePath == null) return;

    if (!context.mounted) return;

    final titleController = TextEditingController(text: p.basenameWithoutExtension(sourcePath));
    final composerController = TextEditingController();
    InstrumentType selectedInstrument = InstrumentType.violin;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Import Sheet Music'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Piece Title (Required)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: composerController,
                    decoration: const InputDecoration(
                      labelText: 'Composer',
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
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.amber),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'All imported pieces are sent directly to the server for OMR processing and metadata cleanup. They can be pushed to students after approval.',
                            style: TextStyle(fontSize: 12, color: Colors.amber[955] ?? Colors.amber[900]),
                          ),
                        ),
                      ],
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
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    final composer = composerController.text.trim();

                    try {
                      // Import piece via provider (no initial student assignment)
                      await ref.read(allPiecesProvider.notifier).importScoreFile(
                        sourcePath,
                        composer: composer.isNotEmpty ? composer : null,
                        primaryInstrument: selectedInstrument.name,
                        assignedProfileId: null,
                      );
                      
                      ref.invalidate(allPiecesProvider);
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Piece import started successfully.')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to import piece: $e')),
                      );
                    }
                  },
                  child: const Text('Import'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReviewDialog(BuildContext context, LibraryEntry entry) {
    final titleController = TextEditingController(text: entry.piece.title);
    final composerController = TextEditingController(text: entry.piece.composer ?? '');
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Review Piece Metadata'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: composerController,
                decoration: const InputDecoration(
                  labelText: 'Composer',
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
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                try {
                  final serverPieceId = entry.piece.serverPieceId;
                  if (serverPieceId != null) {
                    await ref.read(allPiecesProvider.notifier).updateRemoteMetadata(
                      serverPieceId: serverPieceId,
                      title: title,
                      composer: composerController.text.trim(),
                    );
                    
                    await ref.read(allPiecesProvider.notifier).closeWorkflow(
                      serverPieceId: serverPieceId,
                      localPieceId: entry.piece.id,
                    );
                  }

                  ref.invalidate(allPiecesProvider);

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save metadata: $e')),
                  );
                }
              },
              child: const Text('Approve & Ready'),
            ),
          ],
        );
      },
    );
  }
}

class _PieceDetailsDialog extends ConsumerStatefulWidget {
  final LibraryEntry entry;
  final List<Profile> students;
  final int initialTabIndex;

  const _PieceDetailsDialog({
    super.key,
    required this.entry,
    required this.students,
    required this.initialTabIndex,
  });

  @override
  ConsumerState<_PieceDetailsDialog> createState() => _PieceDetailsDialogState();
}

class _PieceDetailsDialogState extends ConsumerState<_PieceDetailsDialog> {
  late TextEditingController _titleController;
  late TextEditingController _composerController;
  late TextEditingController _keyController;
  late TextEditingController _tempoController;
  late TextEditingController _notesController;
  late InstrumentType _selectedInstrument;

  final Set<String> _selectedStudentIds = {};
  bool _savingMetadata = false;
  bool _pushingStudents = false;
  bool _openingMuseScore = false;
  bool _uploadingXml = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry.piece.title);
    _composerController = TextEditingController(text: widget.entry.piece.composer ?? '');
    _keyController = TextEditingController(text: widget.entry.piece.keySignature ?? '');
    _tempoController = TextEditingController(text: widget.entry.piece.tempo ?? '');
    _notesController = TextEditingController(text: widget.entry.piece.notes ?? '');

    final pieceInst = widget.entry.piece.primaryInstrument?.toLowerCase();
    _selectedInstrument = InstrumentType.values.firstWhere(
      (inst) => inst.name.toLowerCase() == pieceInst,
      orElse: () => InstrumentType.other,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _composerController.dispose();
    _keyController.dispose();
    _tempoController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: widget.initialTabIndex,
      length: 3,
      child: AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.entry.piece.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        content: SizedBox(
          width: 500,
          height: 480,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Metadata'),
                  Tab(text: 'Push to Students'),
                  Tab(text: 'MusicXML Edits'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildMetadataTab(),
                    _buildPushTab(),
                    _buildNotationLabTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Piece Title (Required)', isDense: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _composerController,
            decoration: const InputDecoration(labelText: 'Composer', isDense: true),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<InstrumentType>(
            value: _selectedInstrument,
            decoration: const InputDecoration(labelText: 'Instrument', isDense: true),
            items: InstrumentType.values.map((inst) {
              return DropdownMenuItem(
                value: inst,
                child: Text(_instrumentLabel(inst)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedInstrument = val;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keyController,
                  decoration: const InputDecoration(labelText: 'Key Signature', isDense: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _tempoController,
                  decoration: const InputDecoration(labelText: 'Tempo (e.g. 120 bpm)', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes', isDense: true),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savingMetadata ? null : _saveMetadata,
              icon: _savingMetadata 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
              label: const Text('Save & Push Updates to Students'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPushTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Distribute to student libraries:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  for (final s in widget.students) {
                    final isPushed = widget.entry.piece.visibleToProfileIds.contains(s.id);
                    if (!isPushed) {
                      _selectedStudentIds.add(s.id);
                    }
                  }
                });
              },
              child: const Text('Select All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: widget.students.map((student) {
              final isPushed = widget.entry.piece.visibleToProfileIds.contains(student.id) ||
                               widget.entry.piece.assignedProfileId == student.id;
              final isSelected = _selectedStudentIds.contains(student.id);

              return CheckboxListTile(
                title: Text(student.displayName),
                subtitle: Text('${_instrumentLabel(student.instrument)}' + 
                  (isPushed ? ' (Already pushed)' : '')),
                value: isPushed || isSelected,
                onChanged: isPushed
                  ? null
                  : (val) {
                      setState(() {
                        if (val == true) {
                          _selectedStudentIds.add(student.id);
                        } else {
                          _selectedStudentIds.remove(student.id);
                        }
                      });
                    },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_selectedStudentIds.isEmpty || _pushingStudents) ? null : _pushToStudents,
            icon: _pushingStudents
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send),
            label: const Text('Push to Selected Students'),
          ),
        ),
      ],
    );
  }

  Widget _buildNotationLabTab() {
    final canonicalVersion = widget.entry.scoreVersions.firstWhereOrNull(
      (v) => v.format.toLowerCase() == 'musicxml'
    );
    var renderedVersion = widget.entry.scoreVersions.firstWhereOrNull(
      (v) => v.format.toLowerCase() == 'pdf' && v.versionType == 'rendered'
    );
    renderedVersion ??= widget.entry.scoreVersions.firstWhereOrNull(
      (v) => v.format.toLowerCase() == 'pdf' && v.versionType != 'raw'
    );

    if (canonicalVersion == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'No MusicXML version is available for this piece.\nOnly pieces with imported/generated MusicXML can be edited.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MusicXML Editor Integration',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          'Open the MusicXML score in your local notation editor (MuseScore Studio). Save or export your edits, then upload the updated file below.',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 20),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.music_note, color: Colors.blue),
          title: Text(canonicalVersion.title),
          subtitle: const Text('Format: MusicXML'),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openingMuseScore ? null : () => _editInMuseScore(canonicalVersion),
            icon: _openingMuseScore
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.open_in_new),
            label: const Text('Edit in MuseScore'),
          ),
        ),
        const SizedBox(height: 12),
        if (renderedVersion != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _uploadingXml ? null : () => _uploadEditedXml(canonicalVersion, renderedVersion!),
              icon: _uploadingXml
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload),
              label: const Text('Upload Edited MusicXML'),
            ),
          ),
        const Spacer(),
      ],
    );
  }

  Future<void> _saveMetadata() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _savingMetadata = true;
    });

    try {
      final serverPieceId = widget.entry.piece.serverPieceId;
      if (serverPieceId != null) {
        await ref.read(allPiecesProvider.notifier).updateRemoteMetadata(
          serverPieceId: serverPieceId,
          title: title,
          composer: _composerController.text.trim(),
          primaryInstrument: _selectedInstrument.name,
          keySignature: _keyController.text.trim(),
          tempo: _tempoController.text.trim(),
          notes: _notesController.text.trim(),
        );

        if (widget.entry.piece.visibleToProfileIds.isNotEmpty) {
          await ref.read(allPiecesProvider.notifier).pushToProfiles(
            pieceId: widget.entry.piece.id,
            profileIds: widget.entry.piece.visibleToProfileIds,
          );
        }
      }

      ref.invalidate(allPiecesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Metadata saved and updates pushed to student libraries.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save metadata: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingMetadata = false;
        });
      }
    }
  }

  Future<void> _pushToStudents() async {
    if (_selectedStudentIds.isEmpty) return;

    setState(() {
      _pushingStudents = true;
    });

    try {
      await ref.read(allPiecesProvider.notifier).pushToProfiles(
        pieceId: widget.entry.piece.id,
        profileIds: _selectedStudentIds.toList(),
      );

      ref.invalidate(allPiecesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Piece successfully pushed to selected student libraries.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to push: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _pushingStudents = false;
        });
      }
    }
  }

  Future<void> _editInMuseScore(ScoreVersion version) async {
    if (_openingMuseScore || version.remoteUrl == null || version.remoteUrl!.isEmpty) {
      return;
    }

    setState(() {
      _openingMuseScore = true;
    });

    try {
      final repository = ref.read(serverPieceSyncRepositoryProvider);
      final bytes = await repository.downloadBytes(version.remoteUrl!);
      if (bytes.isEmpty) {
        throw StateError('Downloaded MusicXML was empty.');
      }

      final editDirectory = await _getEditDirectory();
      await editDirectory.create(recursive: true);
      final editFile = File(
        p.join(
          editDirectory.path,
          '${_getSafeFileName(widget.entry.piece.title)}-${version.id}.musicxml',
        ),
      );
      await editFile.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(editFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Opened local MusicXML copy. Save edits in MuseScore, then return here to upload.',
            ),
            action: SnackBarAction(
              label: 'Path',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(editFile.path)),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open MusicXML: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _openingMuseScore = false;
        });
      }
    }
  }

  Future<void> _uploadEditedXml(ScoreVersion canonicalVersion, ScoreVersion renderedVersion) async {
    if (_uploadingXml) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['musicxml', 'xml', 'mxl'],
      allowMultiple: false,
      dialogTitle: 'Select edited MusicXML',
    );
    final editedPath = result?.files.single.path;
    if (editedPath == null || editedPath.isEmpty) {
      return;
    }

    setState(() {
      _uploadingXml = true;
    });

    try {
      final serverPieceId = widget.entry.piece.serverPieceId;
      if (serverPieceId == null) {
        throw StateError('Piece does not have a server ID.');
      }

      await ref.read(serverPieceSyncRepositoryProvider).uploadEditedScoreVersion(
        serverPieceId: serverPieceId,
        canonicalScoreVersionId: canonicalVersion.id,
        renderedScoreVersionId: renderedVersion.id,
        filePath: editedPath,
      );

      ref.invalidate(allPiecesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edited MusicXML successfully uploaded. Server is rebuilding.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to upload edited MusicXML: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingXml = false;
        });
      }
    }
  }

  Future<Directory> _getEditDirectory() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return Directory(p.join(downloads.path, 'AZMusic Edits'));
      }
    } catch (_) {}
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'AZMusic Edits'));
  }

  String _getSafeFileName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^\w\s\-\.]'), '');
    return cleaned.trim().replaceAll(RegExp(r'\s+'), '_');
  }
}
