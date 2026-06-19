import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_keys.dart';
import '../../../app/routes/app_router.dart';
import '../../../app/score_reader_launcher.dart';
import '../../../core/import/score_import_picker.dart';
import '../../../domain/entities/library_entry.dart';
import '../../../domain/entities/piece.dart';
import '../../providers/app_providers.dart';
import '../../providers/piece_providers.dart';
import '../../providers/profile_providers.dart';
import 'library_browse_utils.dart';

enum _LibraryBrowseMode {
  title,
  composer,
  book,
  recent,
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  _LibraryBrowseMode _browseMode = _LibraryBrowseMode.title;
  String? _activeJumpLetter;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final student = ref.watch(activeStudentProfileProvider);
    final syncActive = ref.watch(syncStatusProvider);
    final connectionStatus = ref.watch(connectionStatusProvider);
    final bannerState = ref.watch(librarySyncBannerProvider);
    final library = ref.watch(studentLibraryEntriesProvider);
    final theme = Theme.of(context);
    final filteredEntries = _filterEntries(library);
    final railEnabled = _supportsAlphaRail && filteredEntries.isNotEmpty;

    return Scaffold(
      key: AppKeys.libraryScreen,
      backgroundColor: const Color(0xFFF5F5F3),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'library-import-piece',
        onPressed: _importPiece,
        backgroundColor: const Color(0xFF1D9E75),
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        label: const Text('Import piece'),
        icon: const Icon(Icons.add, size: 18),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                    child: Row(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: student?.id == 'student-zora'
                                  ? const Color(0xFFE1F5EE)
                                  : const Color(0xFFEEEDFE),
                              foregroundColor: student?.id == 'student-zora'
                                  ? const Color(0xFF0F6E56)
                                  : const Color(0xFF3C3489),
                              child: Text(
                                (student?.displayName ?? 'ST')
                                    .substring(0, 2)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "${student?.displayName ?? 'Student'}'s library",
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF111111),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        _HeaderIconButton(
                          tooltip: 'Search',
                          icon: Icons.search,
                          onTap: () => _searchFocusNode.requestFocus(),
                        ),
                        _HeaderIconButton(
                          tooltip: 'Parent tools',
                          icon: Icons.notifications_none_outlined,
                          onTap: _openParentTools,
                        ),
                        _HeaderIconButton(
                          tooltip: 'Switch profile',
                          icon: Icons.settings_outlined,
                          onTap: () => Navigator.of(context)
                              .pushReplacementNamed(AppRouter.login),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    color: const Color(0xFFEBEBEB),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _BrowseTab(
                          key: AppKeys.libraryTab('title'),
                          label: 'Title',
                          selected: _browseMode == _LibraryBrowseMode.title,
                          onTap: () =>
                              _selectBrowseMode(_LibraryBrowseMode.title),
                        ),
                        _BrowseTab(
                          key: AppKeys.libraryTab('composer'),
                          label: 'Composer',
                          selected: _browseMode == _LibraryBrowseMode.composer,
                          onTap: () =>
                              _selectBrowseMode(_LibraryBrowseMode.composer),
                        ),
                        _BrowseTab(
                          key: AppKeys.libraryTab('book'),
                          label: 'Book',
                          selected: _browseMode == _LibraryBrowseMode.book,
                          onTap: () =>
                              _selectBrowseMode(_LibraryBrowseMode.book),
                        ),
                        _BrowseTab(
                          key: AppKeys.libraryTab('recent'),
                          label: 'Recent',
                          selected: _browseMode == _LibraryBrowseMode.recent,
                          onTap: () =>
                              _selectBrowseMode(_LibraryBrowseMode.recent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: TextField(
                key: AppKeys.librarySearchField,
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search pieces, composers...',
                  filled: true,
                  fillColor: Color(0xFFF5F5F3),
                  prefixIcon: Icon(Icons.search, color: Color(0xFFAAAAAA)),
                ),
              ),
            ),
            Container(
              key: AppKeys.libraryStatusBanner,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(
                children: [
                  Icon(
                    connectionStatus == 'offline-ready'
                        ? Icons.wifi_off_outlined
                        : syncActive
                            ? Icons.sync
                            : connectionStatus == 'failed-usable'
                                ? Icons.cloud_off_outlined
                                : Icons.cloud_done_outlined,
                    size: 14,
                    color: const Color(0xFF0F6E56),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      bannerState.message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF0F6E56),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  if (_supportsAlphaRail)
                    _VerticalAlphaRail(
                      activeLetter: _activeJumpLetter,
                      enabled: railEnabled,
                      onLetterSelected: (letter) {
                        _jumpToLetter(filteredEntries, letter);
                      },
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => ref
                          .read(allPiecesProvider.notifier)
                          .loadPieces(trigger: SyncTrigger.manualRefresh),
                      child: filteredEntries.isEmpty
                          ? _EmptyLibraryState(
                              query: _searchController.text,
                              onImportScore: _importPiece,
                            )
                          : ListView.builder(
                              key: AppKeys.libraryList,
                              controller: _scrollController,
                              padding:
                                  const EdgeInsets.fromLTRB(12, 10, 12, 24),
                              itemCount: filteredEntries.length,
                              itemBuilder: (context, index) {
                                final entry = filteredEntries[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _LibraryRow(
                                    entry: entry,
                                    onTap: () =>
                                        _openPieceDetail(context, entry),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectBrowseMode(_LibraryBrowseMode browseMode) {
    setState(() {
      _browseMode = browseMode;
      _activeJumpLetter = null;
    });
  }

  Future<void> _importPiece() async {
    final student = ref.read(activeStudentProfileProvider);
    if (student == null) {
      return;
    }

    final sourcePath =
        await ref.read(scoreImportPickerProvider).pickScorePath();
    if (sourcePath == null) {
      return;
    }

    try {
      final importedEntry =
          await ref.read(allPiecesProvider.notifier).importScoreFile(
                sourcePath,
                assignedProfileId: student.id,
              );
      if (!mounted) {
        return;
      }
      final latestEntry =
          ref.read(pieceEntryProvider(importedEntry.piece.id)) ?? importedEntry;
      await ref.read(scoreReaderLauncherProvider).open(
            context,
            ScoreReaderLaunchRequest(
              pieceId: latestEntry.piece.id,
              scoreVersionId: latestEntry.primaryScore.id,
            ),
          );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to import that score right now.')),
      );
    }
  }

  void _openParentTools() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Switch to Parent for review and push tools.')),
    );
    Navigator.of(context).pushReplacementNamed(AppRouter.login);
  }

  List<LibraryEntry> _filterEntries(List<LibraryEntry> entries) {
    final query = _searchController.text.trim();
    final filtered =
        entries.where((entry) => entry.piece.matchesQuery(query)).toList();

    // Book mode: show only pieces whose pieceKind is 'book'.
    if (_browseMode == _LibraryBrowseMode.book) {
      filtered.removeWhere((entry) => entry.piece.pieceKind != 'book');
    }

    filtered.sort((left, right) {
      switch (_browseMode) {
        case _LibraryBrowseMode.title:
          return left.piece.sortTitle.compareTo(right.piece.sortTitle);
        case _LibraryBrowseMode.composer:
          return (left.piece.sortComposer ?? '~')
              .compareTo(right.piece.sortComposer ?? '~');
        case _LibraryBrowseMode.book:
          return (left.piece.bookOrCollection ?? '~')
              .toLowerCase()
              .compareTo((right.piece.bookOrCollection ?? '~').toLowerCase());
        case _LibraryBrowseMode.recent:
          return right.piece.updatedAt.compareTo(left.piece.updatedAt);
      }
    });
    return filtered;
  }

  bool get _supportsAlphaRail => _browseMode != _LibraryBrowseMode.recent;

  LibraryAlphaSelector _alphaSelectorForMode() {
    switch (_browseMode) {
      case _LibraryBrowseMode.title:
        return (entry) => entry.piece.sortTitle;
      case _LibraryBrowseMode.composer:
        return (entry) => entry.piece.sortComposer ?? '';
      case _LibraryBrowseMode.book:
        return (entry) => entry.piece.bookOrCollection ?? '';
      case _LibraryBrowseMode.recent:
        return (_) => '';
    }
  }

  void _jumpToLetter(List<LibraryEntry> filteredEntries, String letter) {
    if (!_supportsAlphaRail || filteredEntries.isEmpty) {
      return;
    }

    final targetIndex = findAlphaJumpIndex(
      filteredEntries,
      letter,
      selector: _alphaSelectorForMode(),
    );
    if (targetIndex == null) {
      return;
    }

    setState(() {
      _activeJumpLetter = letter;
    });

    if (!_scrollController.hasClients) {
      return;
    }

    final rawOffset = targetIndex * 86.0;
    final targetOffset = rawOffset.clamp(
      0.0,
      math.max(0.0, _scrollController.position.maxScrollExtent),
    );
    _scrollController.jumpTo(targetOffset.toDouble());
  }

  void _openPieceDetail(BuildContext context, LibraryEntry entry) {
    // Quick-open: if there's exactly one readable score version, skip the
    // piece detail screen and go straight to the reader.
    final readable = entry.scoreVersions.where((sv) {
      return (sv.format == 'pdf' || sv.format == 'image') &&
          sv.isStudentVisible;
    }).toList();

    if (readable.length == 1) {
      ref.read(scoreReaderLauncherProvider).open(
        context,
        ScoreReaderLaunchRequest(
          pieceId: entry.piece.id,
          scoreVersionId: readable.first.id,
        ),
      );
      return;
    }

    Navigator.of(context).pushNamed(
      AppRouter.pieceDetail,
      arguments: entry.piece.id,
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: const Color(0xFFAAAAAA)),
        ),
      ),
    );
  }
}

class _BrowseTab extends StatelessWidget {
  const _BrowseTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? const Color(0xFF1D9E75) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? const Color(0xFF1D9E75) : const Color(0xFFAAAAAA),
          ),
        ),
      ),
    );
  }
}

class _VerticalAlphaRail extends StatefulWidget {
  const _VerticalAlphaRail({
    required this.activeLetter,
    required this.enabled,
    required this.onLetterSelected,
  });

  final String? activeLetter;
  final bool enabled;
  final ValueChanged<String> onLetterSelected;

  @override
  State<_VerticalAlphaRail> createState() => _VerticalAlphaRailState();
}

class _VerticalAlphaRailState extends State<_VerticalAlphaRail> {
  String? _dragLetter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: widget.enabled
              ? (details) => _selectFromOffset(
                    details.localPosition.dy,
                    constraints.maxHeight,
                    showBubble: false,
                  )
              : null,
          onPanStart: widget.enabled
              ? (details) => _selectFromOffset(
                    details.localPosition.dy,
                    constraints.maxHeight,
                    showBubble: true,
                  )
              : null,
          onPanUpdate: widget.enabled
              ? (details) => _selectFromOffset(
                    details.localPosition.dy,
                    constraints.maxHeight,
                    showBubble: true,
                  )
              : null,
          onPanEnd: (_) => _clearDragBubble(),
          onPanCancel: _clearDragBubble,
          child: Container(
            width: 42,
            margin: const EdgeInsets.fromLTRB(8, 8, 2, 90),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _letters.map((letter) {
                    final selected = widget.activeLetter == letter;
                    return Expanded(
                      child: Container(
                        key: AppKeys.alphaJump(letter),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFE1F5EE)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: widget.enabled
                                ? const Color(0xFF1D9E75)
                                : const Color(0xFFCCCCCC),
                          ),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                ),
                if (_dragLetter != null)
                  Positioned(
                    left: 44,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F6E56),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _dragLetter!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _clearDragBubble() {
    setState(() {
      _dragLetter = null;
    });
  }

  void _selectFromOffset(
    double localDy,
    double height, {
    required bool showBubble,
  }) {
    final slotHeight = height / _letters.length;
    if (slotHeight <= 0) {
      return;
    }

    final index = (localDy / slotHeight).floor().clamp(0, _letters.length - 1);
    final letter = _letters[index];
    if (showBubble) {
      setState(() {
        _dragLetter = letter;
      });
    }
    widget.onLetterSelected(letter);
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({
    required this.entry,
    required this.onTap,
  });

  final LibraryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final piece = entry.piece;
    final subtitle = <String>[
      if (piece.composer?.isNotEmpty ?? false) piece.composer!,
      if (piece.primaryInstrument?.isNotEmpty ?? false)
        piece.primaryInstrument!,
    ].join(' - ');
    final rowStatus = _rowStatus(piece.libraryStatus);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: AppKeys.pieceCard(piece.id),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEBEBEB)),
          ),
          child: Row(
            children: [
              _Thumb(status: piece.libraryStatus),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      piece.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111111),
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFAAAAAA),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 82,
                alignment: Alignment.centerRight,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: rowStatus.background,
                    borderRadius: BorderRadius.circular(20),
                    border: rowStatus.borderColor == null
                        ? null
                        : Border.all(color: rowStatus.borderColor!),
                  ),
                  child: Text(
                    rowStatus.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: rowStatus.foreground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.status});

  final LibraryStatus status;

  @override
  Widget build(BuildContext context) {
    final isWaiting = status == LibraryStatus.processing ||
        status == LibraryStatus.uploadPending;
    return Container(
      width: 32,
      height: 40,
      decoration: BoxDecoration(
        color: isWaiting ? const Color(0xFFFAEEDA) : const Color(0xFFE1F5EE),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        isWaiting ? Icons.autorenew_rounded : Icons.music_note_outlined,
        size: 16,
        color: isWaiting ? const Color(0xFF854F0B) : const Color(0xFF0F6E56),
      ),
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState({
    required this.query,
    required this.onImportScore,
  });

  final String query;
  final VoidCallback onImportScore;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Container(
            key: AppKeys.libraryEmptyState,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEBEBEB)),
            ),
            child: Column(
              children: [
                Icon(
                  hasQuery
                      ? Icons.search_off_outlined
                      : Icons.library_music_outlined,
                  size: 48,
                  color: const Color(0xFF1D9E75),
                ),
                const SizedBox(height: 14),
                Text(
                  hasQuery
                      ? 'No pieces match that search yet.'
                      : 'This student library is waiting for approved pieces.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  hasQuery
                      ? 'Try a different title, composer, or book search.'
                      : 'Import music to start practicing right away. When the server finishes processing and a parent approves it, the cleaned score will replace the original here automatically.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF777777),
                  ),
                ),
                if (!hasQuery) ...[
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: onImportScore,
                    child: const Text('Import music'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RowStatus {
  const _RowStatus({
    required this.label,
    required this.background,
    required this.foreground,
    this.borderColor,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? borderColor;
}

_RowStatus _rowStatus(LibraryStatus status) {
  switch (status) {
    case LibraryStatus.ready:
      return const _RowStatus(
        label: 'Ready',
        background: Color(0xFFE1F5EE),
        foreground: Color(0xFF0F6E56),
      );
    case LibraryStatus.review:
      return const _RowStatus(
        label: 'Review',
        background: Color(0xFFFAEEDA),
        foreground: Color(0xFF854F0B),
      );
    case LibraryStatus.needsEdits:
      return const _RowStatus(
        label: 'Needs edits',
        background: Color(0xFFFAEEDA),
        foreground: Color(0xFF854F0B),
      );
    case LibraryStatus.uploadPending:
      return const _RowStatus(
        label: 'Server',
        background: Color(0xFFFAEEDA),
        foreground: Color(0xFF854F0B),
      );
    case LibraryStatus.processing:
      return const _RowStatus(
        label: 'Processing',
        background: Color(0xFFF5F5F3),
        foreground: Color(0xFFAAAAAA),
        borderColor: Color(0xFFEBEBEB),
      );
    case LibraryStatus.archived:
      return const _RowStatus(
        label: 'Archived',
        background: Color(0xFFF5DDDD),
        foreground: Color(0xFF8A1F1F),
      );
    case LibraryStatus.intake:
      return const _RowStatus(
        label: 'Intake',
        background: Color(0xFFF5F5F3),
        foreground: Color(0xFF777777),
        borderColor: Color(0xFFEBEBEB),
      );
  }
}

const List<String> _letters = <String>[
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
];
