import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../app/app_keys.dart';
import '../../../app/routes/app_router.dart';
import '../../../domain/entities/annotation_layer.dart';
import '../../../domain/entities/library_entry.dart';
import '../../../domain/entities/note_entry.dart';
import '../../../domain/entities/profile.dart';
import '../../../domain/entities/score_version.dart';
import '../../providers/annotation_providers.dart';
import '../../providers/note_providers.dart';
import '../../providers/piece_providers.dart';
import '../../providers/profile_providers.dart';
import 'reader_page_layout.dart';

enum _ReaderModule {
  about,
  media,
  tuner,
  notes,
}

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    this.pieceId,
    this.scoreVersionId,
  });

  final String? pieceId;
  final String? scoreVersionId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final PdfViewerController _pdfController = PdfViewerController();

  _ReaderModule? _activeModule;
  int _currentPage = 1;
  int _pageCount = 1;
  String? _loadError;
  bool _chromeVisible = false;
  bool _reportedPdfSmokeReady = false;
  Timer? _chromeAutoHideTimer;

  @override
  void dispose() {
    _chromeAutoHideTimer?.cancel();
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pieceId == null) {
      return const _ReaderFallbackScaffold(
        title: 'Score reader',
        message: 'Pick a piece from the library before opening the reader.',
      );
    }

    final libraryState = ref.watch(allPiecesProvider);
    final entry = ref.watch(pieceEntryProvider(widget.pieceId!));
    final scoreVersion = ref.watch(
      scoreVersionForPieceProvider(
        (pieceId: widget.pieceId!, scoreVersionId: widget.scoreVersionId),
      ),
    );
    final activeProfile = ref.watch(activeProfileProvider);

    if (entry == null || scoreVersion == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Score reader')),
        body: libraryState.when(
          data: (_) => const _ReaderMessage(
            icon: Icons.description_outlined,
            message:
                'That score is not available in the local library anymore.',
          ),
          error: (error, _) => _ReaderMessage(
            icon: Icons.error_outline,
            message: 'Unable to load the score.\n$error',
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final scoreFile = File(scoreVersion.filePath);
    if (!scoreFile.existsSync()) {
      return const _ReaderFallbackScaffold(
        title: 'Missing file',
        message: 'The imported score file is no longer present on disk.',
      );
    }

    if (scoreVersion.format.toLowerCase() == 'pdf' && !_reportedPdfSmokeReady) {
      _reportedPdfSmokeReady = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('AZMUSIC_PDF_LOAD_OK:${scoreFile.path}:ready');
      });
    }

    final annotationRequest = activeProfile.role == ProfileRole.student
        ? (
            profileId: activeProfile.id,
            scoreVersionId: scoreVersion.id,
            pageNumber: _currentPage,
          )
        : null;
    final annotationState = annotationRequest == null
        ? null
        : ref.watch(annotationPageProvider(annotationRequest));
    final annotationPageState = annotationState?.valueOrNull;
    final isWriteModeActive = (annotationPageState?.isDrawing ?? false) &&
        (annotationPageState?.isVisible ?? true);
    final mediaQuery = MediaQuery.of(context);
    final spreadMode = isLandscapeSpreadEligible(
          format: scoreVersion.format,
          isLandscape: mediaQuery.orientation == Orientation.landscape,
          viewportWidth: mediaQuery.size.width,
          pageCount: _pageCount,
        ) &&
        !isWriteModeActive;
    final pagePositionLabel = readerPagePositionLabel(
      currentPage: _currentPage,
      pageCount: _pageCount,
      spreadMode: spreadMode,
    );
    final chromeVisible =
        _chromeVisible || _activeModule != null || isWriteModeActive;
    final safePadding = mediaQuery.padding;

    return Scaffold(
      key: AppKeys.readerScreen,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildCanvas(
              context,
              entry: entry,
              scoreVersion: scoreVersion,
              scoreFile: scoreFile,
              activeProfile: activeProfile,
              annotationRequest: annotationRequest,
              annotationState: annotationState,
              spreadMode: spreadMode,
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 34,
            child: _ReaderEdgeReveal(
              onReveal: _showChromeTransient,
            ),
          ),
          if (chromeVisible) ...[
            Positioned(
              left: 12,
              top: safePadding.top + 12,
              bottom: safePadding.bottom + 12,
              child: _ReaderChromeSurface(
                child: _ReaderRail(
                  activeModule: _activeModule,
                  onSelect: (module) {
                    _handleModuleSelection(module, annotationRequest);
                  },
                  onBack: () => _handleBack(annotationRequest),
                ),
              ),
            ),
            Positioned(
              left: 88,
              right: 12,
              top: safePadding.top + 12,
              child: _ReaderChromeSurface(
                child: _ReaderTopBar(
                  entry: entry,
                  scoreVersion: scoreVersion,
                  readableScoreVersions:
                      _readableScoreVersions(entry, scoreVersion),
                  onSelectScoreVersion: (scoreVersionId) {
                    if (scoreVersionId == scoreVersion.id) {
                      return;
                    }
                    Navigator.of(context).pushReplacementNamed(
                      AppRouter.reader,
                      arguments: {
                        'pieceId': entry.piece.id,
                        'scoreVersionId': scoreVersionId,
                      },
                    );
                  },
                  pagePositionLabel: pagePositionLabel,
                  isWriteModeActive: isWriteModeActive,
                  canToggleWriteMode:
                      activeProfile.role == ProfileRole.student &&
                          annotationRequest != null,
                  onToggleWriteMode: annotationRequest == null
                      ? null
                      : () => _toggleWriteMode(
                            annotationRequest,
                            annotationPageState,
                          ),
                  onPreviousPage: _currentPage > 1
                      ? () {
                          _showChromeTransient();
                          _jumpToPage(
                            previousReaderTarget(
                              currentPage: _currentPage,
                              spreadMode: spreadMode,
                            ),
                            spreadMode: spreadMode,
                          );
                        }
                      : null,
                  onNextPage: _currentPage < _pageCount
                      ? () {
                          _showChromeTransient();
                          _jumpToPage(
                            nextReaderTarget(
                              currentPage: _currentPage,
                              pageCount: _pageCount,
                              spreadMode: spreadMode,
                            ),
                            spreadMode: spreadMode,
                          );
                        }
                      : null,
                ),
              ),
            ),
            if (_activeModule != null)
              Positioned(
                left: 88,
                top: safePadding.top + 112,
                bottom: safePadding.bottom + 12,
                width: 340,
                child: _ReaderChromeSurface(
                  child: _ReaderModulePanel(
                    module: _activeModule!,
                    entry: entry,
                    scoreVersion: scoreVersion,
                    currentPage: _currentPage,
                    pageCount: _pageCount,
                    activeProfile: activeProfile,
                    annotationRequest: annotationRequest,
                    annotationState: annotationState,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showChromeTransient() {
    _chromeAutoHideTimer?.cancel();
    if (!_chromeVisible && mounted) {
      setState(() {
        _chromeVisible = true;
      });
    }
    _chromeAutoHideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _activeModule != null) {
        return;
      }
      setState(() {
        _chromeVisible = false;
      });
    });
  }

  void _cancelChromeAutoHide() {
    _chromeAutoHideTimer?.cancel();
    _chromeAutoHideTimer = null;
  }

  void _handleModuleSelection(
    _ReaderModule module,
    ({
      String profileId,
      String scoreVersionId,
      int pageNumber
    })? annotationRequest,
  ) {
    final nextModule = _activeModule == module ? null : module;
    _cancelChromeAutoHide();
    setState(() {
      _activeModule = nextModule;
      _chromeVisible = true;
    });
    if (nextModule == null) {
      _showChromeTransient();
    }
  }

  void _handleBack(
    ({
      String profileId,
      String scoreVersionId,
      int pageNumber
    })? annotationRequest,
  ) async {
    _cancelChromeAutoHide();
    _stopDrawing(annotationRequest);
    final fallbackRoute =
        ref.read(activeProfileProvider).role == ProfileRole.parent
            ? AppRouter.parentHome
            : AppRouter.library;
    final didPop = await Navigator.of(context).maybePop();
    if (!didPop && mounted) {
      Navigator.of(context).pushReplacementNamed(fallbackRoute);
    }
  }

  void _stopDrawing(
    ({
      String profileId,
      String scoreVersionId,
      int pageNumber
    })? annotationRequest,
  ) {
    if (annotationRequest == null) {
      return;
    }
    final current =
        ref.read(annotationPageProvider(annotationRequest)).valueOrNull;
    if (current?.isDrawing ?? false) {
      ref
          .read(annotationPageProvider(annotationRequest).notifier)
          .setDrawing(false);
    }
  }

  Widget _buildCanvas(
    BuildContext context, {
    required LibraryEntry entry,
    required ScoreVersion scoreVersion,
    required File scoreFile,
    required Profile activeProfile,
    required ({
      String profileId,
      String scoreVersionId,
      int pageNumber
    })? annotationRequest,
    required AsyncValue<AnnotationPageState>? annotationState,
    required bool spreadMode,
  }) {
    if (_loadError != null) {
      return _ReaderMessage(
        icon: Icons.picture_as_pdf_outlined,
        message: _loadError!,
      );
    }

    final baseCanvas = _buildBaseCanvas(
      context,
      entry: entry,
      scoreVersion: scoreVersion,
      scoreFile: scoreFile,
      activeProfile: activeProfile,
      spreadMode: spreadMode,
    );

    if (spreadMode ||
        activeProfile.role != ProfileRole.student ||
        annotationRequest == null) {
      return baseCanvas;
    }

    final pageState = annotationState?.valueOrNull;
    final isVisible = pageState?.isVisible ?? true;
    final isDrawing = (pageState?.isDrawing ?? false) && isVisible;

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = constraints.biggest;
        return Stack(
          fit: StackFit.expand,
          children: [
            baseCanvas,
            Positioned.fill(
              child: CustomPaint(
                painter: _AnnotationPainter(
                  strokes: isVisible
                      ? pageState?.strokes ?? const <AnnotationStroke>[]
                      : const <AnnotationStroke>[],
                  activeStroke: isVisible
                      ? pageState?.activeStroke ?? const <OffsetPoint>[]
                      : const <OffsetPoint>[],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !isDrawing,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) {
                    final notifier = ref.read(
                      annotationPageProvider(annotationRequest).notifier,
                    );
                    notifier.beginStroke();
                    notifier.addPoint(
                      _normalizeOffset(details.localPosition, canvasSize),
                    );
                  },
                  onPanUpdate: (details) {
                    ref
                        .read(
                            annotationPageProvider(annotationRequest).notifier)
                        .addPoint(
                          _normalizeOffset(details.localPosition, canvasSize),
                        );
                  },
                  onPanEnd: (_) {
                    ref
                        .read(
                            annotationPageProvider(annotationRequest).notifier)
                        .commitStroke();
                  },
                  onPanCancel: () {
                    ref
                        .read(
                            annotationPageProvider(annotationRequest).notifier)
                        .commitStroke();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBaseCanvas(
    BuildContext context, {
    required LibraryEntry entry,
    required ScoreVersion scoreVersion,
    required File scoreFile,
    required Profile activeProfile,
    required bool spreadMode,
  }) {
    switch (scoreVersion.format.toLowerCase()) {
      case 'pdf':
        if (!spreadMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted ||
                _pdfController.pageCount <= 0 ||
                _pdfController.pageNumber == _currentPage ||
                _pageCount < _currentPage) {
              return;
            }
            _pdfController.jumpToPage(_currentPage);
          });
        }
        if (spreadMode) {
          return _PdfSpreadCanvas(
            scoreFile: scoreFile,
            pageCount: _pageCount,
            currentPage: _currentPage,
            activeProfile: activeProfile,
            scoreVersionId: scoreVersion.id,
            onPageSelected: (pageNumber) {
              if (!mounted) {
                return;
              }
              setState(() {
                _currentPage = pageNumber;
              });
            },
          );
        }
        return SfPdfViewer.file(
          scoreFile,
          controller: _pdfController,
          pageLayoutMode: PdfPageLayoutMode.single,
          pageSpacing: 0,
          scrollDirection: PdfScrollDirection.horizontal,
          canShowPaginationDialog: false,
          canShowScrollHead: false,
          canShowScrollStatus: false,
          onDocumentLoaded: (details) {
            debugPrint(
              'AZMUSIC_PDF_LOAD_OK:${scoreFile.path}:${details.document.pages.count}',
            );
            if (!mounted) {
              return;
            }
            setState(() {
              _pageCount = details.document.pages.count;
              _loadError = null;
            });
            if (_currentPage > 1) {
              _pdfController.jumpToPage(_currentPage);
            }
          },
          onPageChanged: (details) {
            if (!mounted) {
              return;
            }
            setState(() {
              _currentPage = details.newPageNumber;
            });
          },
          onDocumentLoadFailed: (details) {
            debugPrint(
              'AZMUSIC_PDF_LOAD_FAILED:${details.error}:${details.description}',
            );
            if (!mounted) {
              return;
            }
            setState(() {
              _loadError = 'Unable to open the PDF for ${entry.piece.title}.\n'
                  '${details.error}: ${details.description}';
            });
          },
        );
      case 'image':
        if (_pageCount != 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _pageCount = 1;
              _currentPage = 1;
            });
          });
        }
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Center(
            child: Image.file(
              scoreFile,
              fit: BoxFit.contain,
            ),
          ),
        );
      default:
        return _ReaderMessage(
          icon: Icons.warning_amber_outlined,
          message:
              '${scoreVersion.format} is not supported in the reader yet for ${entry.piece.title}.',
        );
    }
  }

  void _jumpToPage(
    int pageNumber, {
    required bool spreadMode,
  }) {
    if (!spreadMode) {
      _pdfController.jumpToPage(pageNumber);
    }
    setState(() {
      _currentPage = pageNumber;
    });
  }

  void _toggleWriteMode(
    ({
      String profileId,
      String scoreVersionId,
      int pageNumber
    }) annotationRequest,
    AnnotationPageState? annotationPageState,
  ) {
    final notifier =
        ref.read(annotationPageProvider(annotationRequest).notifier);
    if (!(annotationPageState?.isVisible ?? true)) {
      notifier.setVisibility(true);
    }
    final nextDrawingState = !(annotationPageState?.isDrawing ?? false);
    notifier.setDrawing(nextDrawingState);
    if (nextDrawingState) {
      _cancelChromeAutoHide();
      setState(() {
        _chromeVisible = true;
      });
    } else {
      _showChromeTransient();
    }
  }

  OffsetPoint _normalizeOffset(Offset localPosition, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return const OffsetPoint(x: 0, y: 0);
    }
    return OffsetPoint(
      x: (localPosition.dx / size.width).clamp(0.0, 1.0),
      y: (localPosition.dy / size.height).clamp(0.0, 1.0),
    );
  }
}

class _ReaderEdgeReveal extends StatelessWidget {
  const _ReaderEdgeReveal({
    required this.onReveal,
  });

  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onReveal,
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 120) {
          onReveal();
        }
      },
      child: const SizedBox.expand(),
    );
  }
}

class _ReaderChromeSurface extends StatelessWidget {
  const _ReaderChromeSurface({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.94),
      elevation: 14,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _ReaderRail extends StatelessWidget {
  const _ReaderRail({
    required this.activeModule,
    required this.onSelect,
    required this.onBack,
  });

  final _ReaderModule? activeModule;
  final ValueChanged<_ReaderModule> onSelect;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 64,
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          const SizedBox(height: 18),
          Text(
            'AZ',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _RailButton(
            key: AppKeys.aboutModuleButton,
            icon: Icons.info_outline,
            selected: activeModule == _ReaderModule.about,
            onTap: () => onSelect(_ReaderModule.about),
          ),
          _RailButton(
            key: AppKeys.mediaModuleButton,
            icon: Icons.play_circle_outline,
            selected: activeModule == _ReaderModule.media,
            onTap: () => onSelect(_ReaderModule.media),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 28,
            child: Divider(color: theme.colorScheme.outlineVariant),
          ),
          _RailButton(
            key: AppKeys.tunerModuleButton,
            icon: Icons.tune_outlined,
            selected: activeModule == _ReaderModule.tuner,
            onTap: () => onSelect(_ReaderModule.tuner),
          ),
          _RailButton(
            key: AppKeys.notesModuleButton,
            icon: Icons.note_alt_outlined,
            selected: activeModule == _ReaderModule.notes,
            onTap: () => onSelect(_ReaderModule.notes),
          ),
          const Spacer(),
          _RailButton(
            icon: Icons.arrow_back_outlined,
            selected: false,
            onTap: onBack,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    super.key,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color:
            selected ? theme.colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

List<ScoreVersion> _readableScoreVersions(
  LibraryEntry entry,
  ScoreVersion current,
) {
  final versions = entry.scoreVersions
      .where(
        (version) =>
            (version.isStudentVisible || version.id == current.id) &&
            (version.format == 'pdf' || version.format == 'image'),
      )
      .toList(growable: false);
  if (!versions.any((version) => version.id == current.id) &&
      (current.format == 'pdf' || current.format == 'image')) {
    versions.add(current);
  }
  return versions;
}

String _readerVersionLabel(ScoreVersion version) {
  final title = version.title.toLowerCase();
  if (title.contains('original')) {
    return 'Original PDF';
  }
  if (title.contains('student') ||
      title.contains('processed') ||
      version.versionType == 'approved') {
    return 'Student PDF';
  }
  return version.title;
}

class _ReaderTopBar extends StatelessWidget {
  const _ReaderTopBar({
    required this.entry,
    required this.scoreVersion,
    required this.readableScoreVersions,
    required this.onSelectScoreVersion,
    required this.pagePositionLabel,
    required this.isWriteModeActive,
    required this.canToggleWriteMode,
    required this.onToggleWriteMode,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final LibraryEntry entry;
  final ScoreVersion scoreVersion;
  final List<ScoreVersion> readableScoreVersions;
  final ValueChanged<String> onSelectScoreVersion;
  final String pagePositionLabel;
  final bool isWriteModeActive;
  final bool canToggleWriteMode;
  final VoidCallback? onToggleWriteMode;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = [
      entry.piece.title,
      if (entry.piece.composer?.isNotEmpty ?? false) entry.piece.composer!,
    ].join(' - ');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scoreVersion.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isWriteModeActive
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isWriteModeActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        isWriteModeActive
                            ? 'Write mode: drag writes on the page'
                            : 'Read mode: swipe turns pages',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isWriteModeActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (canToggleWriteMode)
                      FilledButton.tonalIcon(
                        onPressed: onToggleWriteMode,
                        icon: Icon(
                          isWriteModeActive
                              ? Icons.edit_off_outlined
                              : Icons.draw_outlined,
                        ),
                        label: Text(
                          isWriteModeActive
                              ? 'Exit write mode'
                              : 'Enter write mode',
                        ),
                      ),
                    if (readableScoreVersions.length > 1)
                      DropdownButton<String>(
                        value: scoreVersion.id,
                        onChanged: (value) {
                          if (value != null) {
                            onSelectScoreVersion(value);
                          }
                        },
                        items: readableScoreVersions
                            .map(
                              (version) => DropdownMenuItem<String>(
                                value: version.id,
                                child: Text(_readerVersionLabel(version)),
                              ),
                            )
                            .toList(growable: false),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Previous page',
            onPressed: onPreviousPage,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(pagePositionLabel),
          IconButton(
            tooltip: 'Next page',
            onPressed: onNextPage,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _ReaderModulePanel extends StatelessWidget {
  const _ReaderModulePanel({
    required this.module,
    required this.entry,
    required this.scoreVersion,
    required this.currentPage,
    required this.pageCount,
    required this.activeProfile,
    required this.annotationRequest,
    required this.annotationState,
  });

  final _ReaderModule module;
  final LibraryEntry entry;
  final ScoreVersion scoreVersion;
  final int currentPage;
  final int pageCount;
  final Profile activeProfile;
  final ({
    String profileId,
    String scoreVersionId,
    int pageNumber
  })? annotationRequest;
  final AsyncValue<AnnotationPageState>? annotationState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(
          right: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          switch (module) {
            _ReaderModule.about =>
              _AboutModule(entry: entry, scoreVersion: scoreVersion),
            _ReaderModule.media => const _PlaceholderModule(
                title: 'Play media',
                icon: Icons.headphones_outlined,
                body:
                    'Approved practice media will live here once the score-review loop is locked.',
              ),
            _ReaderModule.tuner => const _PlaceholderModule(
                title: 'Tuner and metronome',
                icon: Icons.tune_outlined,
                body:
                    'This slot is intentionally stable now so practice tools can land without reshaping reader navigation.',
              ),
            _ReaderModule.notes => _NotesModule(
                entry: entry,
                scoreVersion: scoreVersion,
                currentPage: currentPage,
                pageCount: pageCount,
                activeProfile: activeProfile,
                annotationRequest: annotationRequest,
                annotationState: annotationState,
              ),
          },
        ],
      ),
    );
  }
}

class _PdfSpreadCanvas extends ConsumerStatefulWidget {
  const _PdfSpreadCanvas({
    required this.scoreFile,
    required this.pageCount,
    required this.currentPage,
    required this.activeProfile,
    required this.scoreVersionId,
    required this.onPageSelected,
  });

  final File scoreFile;
  final int pageCount;
  final int currentPage;
  final Profile activeProfile;
  final String scoreVersionId;
  final ValueChanged<int> onPageSelected;

  @override
  ConsumerState<_PdfSpreadCanvas> createState() => _PdfSpreadCanvasState();
}

class _PdfSpreadCanvasState extends ConsumerState<_PdfSpreadCanvas> {
  late final PageController _pageController;
  late Future<Uint8List> _documentBytesFuture;
  final Map<int, Future<PdfRaster?>> _rasterCache = <int, Future<PdfRaster?>>{};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: spreadIndexForPage(widget.currentPage),
    );
    _documentBytesFuture = widget.scoreFile.readAsBytes();
  }

  @override
  void didUpdateWidget(covariant _PdfSpreadCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scoreFile.path != widget.scoreFile.path) {
      _documentBytesFuture = widget.scoreFile.readAsBytes();
      _rasterCache.clear();
    }

    final targetPage = spreadIndexForPage(widget.currentPage);
    if (_pageController.hasClients &&
        (_pageController.page?.round() ?? targetPage) != targetPage) {
      _pageController.jumpToPage(targetPage);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: spreadCountForPages(widget.pageCount),
      onPageChanged: (index) {
        widget.onPageSelected(pageForSpreadIndex(index));
      },
      itemBuilder: (context, index) {
        final leftPage = pageForSpreadIndex(index);
        final rightPage =
            leftPage + 1 <= widget.pageCount ? leftPage + 1 : null;
        return Row(
          children: [
            Expanded(
              child: _SpreadPagePane(
                pageNumber: leftPage,
                selected: widget.currentPage == leftPage,
                rasterFuture: _loadRaster(leftPage),
                activeProfile: widget.activeProfile,
                scoreVersionId: widget.scoreVersionId,
                onTap: widget.onPageSelected,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: rightPage == null
                  ? const _SpreadPlaceholderPage()
                  : _SpreadPagePane(
                      pageNumber: rightPage,
                      selected: widget.currentPage == rightPage,
                      rasterFuture: _loadRaster(rightPage),
                      activeProfile: widget.activeProfile,
                      scoreVersionId: widget.scoreVersionId,
                      onTap: widget.onPageSelected,
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<PdfRaster?> _loadRaster(int pageNumber) {
    return _rasterCache.putIfAbsent(pageNumber, () async {
      final documentBytes = await _documentBytesFuture;
      await for (final raster in Printing.raster(
        documentBytes,
        pages: [pageNumber - 1],
        dpi: 144,
      )) {
        return raster;
      }
      return null;
    });
  }
}

class _SpreadPagePane extends ConsumerWidget {
  const _SpreadPagePane({
    required this.pageNumber,
    required this.selected,
    required this.rasterFuture,
    required this.activeProfile,
    required this.scoreVersionId,
    required this.onTap,
  });

  final int pageNumber;
  final bool selected;
  final Future<PdfRaster?> rasterFuture;
  final Profile activeProfile;
  final String scoreVersionId;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final annotationRequest = activeProfile.role == ProfileRole.student
        ? (
            profileId: activeProfile.id,
            scoreVersionId: scoreVersionId,
            pageNumber: pageNumber,
          )
        : null;
    final annotationState = annotationRequest == null
        ? null
        : ref.watch(annotationPageProvider(annotationRequest));
    final pageState = annotationState?.valueOrNull;
    final isVisible = pageState?.isVisible ?? true;

    return Semantics(
      selected: selected,
      label: 'Page $pageNumber',
      child: GestureDetector(
        onTap: () => onTap(pageNumber),
        child: ColoredBox(
          color: theme.colorScheme.surface,
          child: FutureBuilder<PdfRaster?>(
            future: rasterFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final raster = snapshot.data;
              if (raster == null) {
                return const Center(child: Text('Unable to render this page.'));
              }
              return Center(
                child: AspectRatio(
                  aspectRatio: raster.width / raster.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(
                        image: PdfRasterImage(raster),
                        fit: BoxFit.fill,
                      ),
                      if (isVisible)
                        CustomPaint(
                          painter: _AnnotationPainter(
                            strokes: pageState?.strokes ??
                                const <AnnotationStroke>[],
                            activeStroke: const <OffsetPoint>[],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SpreadPlaceholderPage extends StatelessWidget {
  const _SpreadPlaceholderPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Text(
        'End of score',
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AboutModule extends StatelessWidget {
  const _AboutModule({
    required this.entry,
    required this.scoreVersion,
  });

  final LibraryEntry entry;
  final ScoreVersion scoreVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About this piece',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          entry.piece.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (entry.piece.composer?.isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          Text(entry.piece.composer!),
        ],
        const SizedBox(height: 16),
        Text(
          'This panel is reserved for approved context, book metadata, and family-ready notes about the piece.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(scoreVersion.format.toUpperCase())),
            if (entry.piece.primaryInstrument?.isNotEmpty ?? false)
              Chip(label: Text(entry.piece.primaryInstrument!)),
            if (entry.piece.bookOrCollection?.isNotEmpty ?? false)
              Chip(label: Text(entry.piece.bookOrCollection!)),
          ],
        ),
      ],
    );
  }
}

class _PlaceholderModule extends StatelessWidget {
  const _PlaceholderModule({
    required this.title,
    required this.icon,
    required this.body,
  });

  final String title;
  final IconData icon;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotesModule extends ConsumerStatefulWidget {
  const _NotesModule({
    required this.entry,
    required this.scoreVersion,
    required this.currentPage,
    required this.pageCount,
    required this.activeProfile,
    required this.annotationRequest,
    required this.annotationState,
  });

  final LibraryEntry entry;
  final ScoreVersion scoreVersion;
  final int currentPage;
  final int pageCount;
  final Profile activeProfile;
  final ({
    String profileId,
    String scoreVersionId,
    int pageNumber
  })? annotationRequest;
  final AsyncValue<AnnotationPageState>? annotationState;

  @override
  ConsumerState<_NotesModule> createState() => _NotesModuleState();
}

class _NotesModuleState extends ConsumerState<_NotesModule> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.activeProfile.role != ProfileRole.student) {
      return const _PlaceholderModule(
        title: 'Notes',
        icon: Icons.lock_outline,
        body:
            'Notes are available in student mode. Parent mode keeps this reader focused on review and approval.',
      );
    }

    final request = (
      profileId: widget.activeProfile.id,
      pieceId: widget.entry.piece.id,
      scoreVersionId: widget.scoreVersion.id,
    );
    final notesState = ref.watch(pieceNotesProvider(request));
    final annotationPageState = widget.annotationState?.valueOrNull;
    final pageStrokeCount = annotationPageState?.strokes.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Notebook for ${widget.entry.piece.title}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Score markup',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Write mode lets this page own drag gestures. Read mode restores swipe navigation immediately.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                key: AppKeys.notesLayerVisibilityToggle,
                contentPadding: EdgeInsets.zero,
                value: annotationPageState?.isVisible ?? true,
                onChanged: widget.annotationRequest == null
                    ? null
                    : (value) => ref
                        .read(
                          annotationPageProvider(widget.annotationRequest!)
                              .notifier,
                        )
                        .setVisibility(value),
                title: const Text('Show notes layer'),
                subtitle: Text(
                  pageStrokeCount == 0
                      ? 'No saved marks on this page yet.'
                      : '$pageStrokeCount saved mark${pageStrokeCount == 1 ? '' : 's'} on this page.',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: AppKeys.notesDrawModeToggle,
                      onPressed: widget.annotationRequest == null
                          ? null
                          : () => _toggleDrawing(annotationPageState),
                      icon: Icon(
                        annotationPageState?.isDrawing ?? false
                            ? Icons.edit_off_outlined
                            : Icons.draw_outlined,
                      ),
                      label: Text(
                        annotationPageState?.isDrawing ?? false
                            ? 'Exit write mode'
                            : 'Enter write mode',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    key: AppKeys.notesClearPageButton,
                    onPressed:
                        pageStrokeCount == 0 || widget.annotationRequest == null
                            ? null
                            : _clearPageMarkup,
                    icon: const Icon(Icons.layers_clear_outlined),
                    label: const Text('Clear page'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                annotationPageState?.isDrawing ?? false
                    ? 'Write mode is active. Drag on the score to mark the page, and page swipe is paused on that surface.'
                    : 'Read mode is active. Swipe across the score to turn pages, then enter write mode when you want to annotate.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: AppKeys.notesComposerField,
          controller: _noteController,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Add a typed note for page ${widget.currentPage}...',
            suffixIcon: IconButton(
              tooltip: 'Save note',
              onPressed: () => _addNote(request),
              icon: const Icon(Icons.add_comment_outlined),
            ),
          ),
          onSubmitted: (_) => _addNote(request),
        ),
        const SizedBox(height: 12),
        Text(
          'Typed notes from this reader view are tagged to page ${widget.currentPage} of ${widget.pageCount}.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        notesState.when(
          data: (notes) {
            if (notes.isEmpty) {
              return const _PlaceholderModule(
                title: 'Notes',
                icon: Icons.menu_book_outlined,
                body:
                    'This notebook is empty. Add a reminder, fingering note, or practice cue here.',
              );
            }
            return Column(
              children: notes
                  .map(
                    (note) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _NoteCard(
                        note: note,
                        onEdit: () => _editNote(request, note),
                        onDelete: () => ref
                            .read(pieceNotesProvider(request).notifier)
                            .deleteNote(note.id),
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
          error: (error, _) => Text(
            'Unable to load notes.\n$error',
            style: theme.textTheme.bodySmall,
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }

  Future<void> _addNote(NotesNotebookRequest request) async {
    final text = _noteController.text.trim();
    if (text.isEmpty) {
      return;
    }
    await ref.read(pieceNotesProvider(request).notifier).addNote(
          text: text,
          pageNumber: widget.scoreVersion.format.toLowerCase() == 'image'
              ? 1
              : widget.currentPage,
        );
    _noteController.clear();
  }

  void _toggleDrawing(AnnotationPageState? annotationPageState) {
    final annotationRequest = widget.annotationRequest;
    if (annotationRequest == null) {
      return;
    }
    final notifier =
        ref.read(annotationPageProvider(annotationRequest).notifier);
    if (!(annotationPageState?.isVisible ?? true)) {
      notifier.setVisibility(true);
    }
    notifier.setDrawing(!(annotationPageState?.isDrawing ?? false));
  }

  Future<void> _clearPageMarkup() async {
    final annotationRequest = widget.annotationRequest;
    if (annotationRequest == null) {
      return;
    }
    await ref.read(annotationPageProvider(annotationRequest).notifier).clear();
  }

  Future<void> _editNote(NotesNotebookRequest request, NoteEntry note) async {
    final controller = TextEditingController(text: note.text);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit note'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 6,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (accepted != true) {
      return;
    }
    await ref.read(pieceNotesProvider(request).notifier).updateNote(
          noteId: note.id,
          text: controller.text,
        );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  final NoteEntry note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: AppKeys.noteCard(note.id),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (note.pageNumber != null)
                Chip(
                  label: Text('Page ${note.pageNumber}'),
                  visualDensity: VisualDensity.compact,
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Edit note',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete note',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Text(note.text),
        ],
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  const _AnnotationPainter({
    required this.strokes,
    required this.activeStroke,
  });

  final List<AnnotationStroke> strokes;
  final List<OffsetPoint> activeStroke;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _paintStroke(canvas, size, stroke);
    }
    if (activeStroke.length >= 2) {
      _paintPoints(
        canvas,
        size,
        points: activeStroke,
        color: _resolveStrokeColor(StrokeColor.orange, StrokeTool.pen),
        strokeWidth: 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activeStroke != activeStroke;
  }

  void _paintStroke(Canvas canvas, Size size, AnnotationStroke stroke) {
    if (stroke.points.length < 2) {
      return;
    }
    _paintPoints(
      canvas,
      size,
      points: stroke.points,
      color: _resolveStrokeColor(stroke.color, stroke.tool),
      strokeWidth: stroke.strokeWidth,
    );
  }

  void _paintPoints(
    Canvas canvas,
    Size size, {
    required List<OffsetPoint> points,
    required Color color,
    required double strokeWidth,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(points.first.x * size.width, points.first.y * size.height);
    for (final point in points.skip(1)) {
      path.lineTo(point.x * size.width, point.y * size.height);
    }
    canvas.drawPath(path, paint);
  }

  Color _resolveStrokeColor(StrokeColor color, StrokeTool tool) {
    final baseColor = switch (color) {
      StrokeColor.red => const Color(0xFFE2534D),
      StrokeColor.blue => const Color(0xFF3E6FDD),
      StrokeColor.green => const Color(0xFF2E8B57),
      StrokeColor.yellow => const Color(0xFFE3B341),
      StrokeColor.orange => const Color(0xFFE47C3C),
      StrokeColor.purple => const Color(0xFF7D5BBE),
      StrokeColor.black => const Color(0xFF202020),
    };
    return tool == StrokeTool.highlighter
        ? baseColor.withValues(alpha: 0.42)
        : baseColor;
  }
}

class _ReaderFallbackScaffold extends StatelessWidget {
  const _ReaderFallbackScaffold({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _ReaderMessage(
        icon: Icons.menu_book_outlined,
        message: message,
      ),
    );
  }
}

class _ReaderMessage extends StatelessWidget {
  const _ReaderMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
