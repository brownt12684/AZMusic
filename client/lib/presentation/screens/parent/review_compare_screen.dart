import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../app/app_keys.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../../data/repositories/server_piece_sync_repository.dart';
import '../../../domain/entities/review_candidate_package.dart';
import '../../providers/app_providers.dart';
import '../../providers/parent_workflow_refresh.dart';
import '../../providers/piece_providers.dart';
import '../../providers/processing_settings_providers.dart';
import '../../providers/review_providers.dart';

@visibleForTesting
bool debugUseReviewPdfPlaceholder = false;

enum _CompareMode {
  original,
  overlay,
  sideBySide,
  processed,
}

class ReviewCompareScreen extends ConsumerStatefulWidget {
  const ReviewCompareScreen({
    super.key,
    this.itemId,
  });

  final String? itemId;

  @override
  ConsumerState<ReviewCompareScreen> createState() =>
      _ReviewCompareScreenState();
}

class _ReviewCompareScreenState extends ConsumerState<ReviewCompareScreen> {
  final PdfViewerController _rawController = PdfViewerController();
  final PdfViewerController _candidateController = PdfViewerController();

  _CompareMode _compareMode = _CompareMode.sideBySide;
  int _currentPage = 1;
  int _pageCount = 1;
  int _renderRefreshToken = 0;
  String? _selectedCandidateId;
  bool _submitting = false;
  final Set<String> _prefetchedReviewItemIds = <String>{};

  @override
  void didUpdateWidget(covariant ReviewCompareScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId) {
      _submitting = false;
    }
  }

  @override
  void dispose() {
    _rawController.dispose();
    _candidateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemId == null) {
      return const _ReviewFallbackScaffold(
        title: 'Score review',
        message: 'Open a review item from the parent queue first.',
      );
    }

    final reviewItem = ref.watch(reviewItemDetailProvider(widget.itemId!));
    return Scaffold(
      key: AppKeys.reviewCompareScreen,
      appBar: AppBar(
        title: const Text('Metadata and student PDF review'),
      ),
      body: reviewItem.when(
        data: (item) => _buildLoadedState(context, item),
        error: (error, _) => _ReviewFallbackScaffold(
          title: 'Score review',
          message: 'Unable to load this review item.\n$error',
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, ReviewQueueEntry item) {
    _prefetchNextReviewItem(item.id);
    final theme = Theme.of(context);
    final baseCandidateData = item.candidateData;
    final candidateOptions = _omrCandidateOptionsFrom(baseCandidateData);
    final selectedCandidate = _selectedOmrCandidateOption(
      baseCandidateData,
      candidateOptions,
      _selectedCandidateId,
    );
    final candidateData =
        _activeCandidateData(baseCandidateData, selectedCandidate);
    final rawUrl = candidateData['raw_file_url'] as String? ?? '';
    final rawContentType = candidateData['raw_content_type'] as String? ?? '';
    final renderedUrl = candidateData['rendered_file_url'] as String? ?? '';
    final canonicalUrl = candidateData['canonical_file_url'] as String? ?? '';
    final renderedScoreVersionId =
        candidateData['score_version_id'] as String? ?? '';
    final canonicalScoreVersionId =
        candidateData['canonical_score_version_id'] as String? ?? '';
    final renderValidationStatus =
        _metadataText(candidateData['render_validation_status']);
    final renderValidationError =
        _metadataText(candidateData['render_validation_error']);
    final isRenderBlocked = renderedScoreVersionId.isNotEmpty &&
        renderValidationStatus != null &&
        renderValidationStatus != 'valid';
    final displayedRenderedUrl =
        _cacheBustedUrl(renderedUrl, _renderRefreshToken);
    final summary = candidateData['summary'] as String? ?? item.description;
    final provenance =
        candidateData['provenance'] as String? ?? 'deterministic';
    final confidence = (candidateData['confidence'] as num?)?.toDouble();
    final pieceTitle = candidateData['piece_title'] as String? ?? item.title;
    final processedMetadata =
        _metadataMapFrom(candidateData['processed_metadata']);
    final catalogMetadata = _metadataMapFrom(candidateData['catalog_metadata']);
    final catalogSuggestions =
        _metadataListFrom(candidateData['catalog_suggestions']);
    final catalogSuggestionFields = _firstSuggestionFields(catalogSuggestions);
    final metadataConflicts = _metadataConflicts(
      currentMetadata:
          catalogMetadata.isNotEmpty ? catalogMetadata : processedMetadata,
      suggestions: catalogSuggestions,
    );
    final validationWarnings = {
      ..._stringListFrom(candidateData['warnings']),
      ..._stringListFrom(candidateData['validation_warnings']),
    }.toList(growable: false);
    final processingStage = _metadataText(candidateData['processing_stage']);
    final isMetadataReviewItem = processingStage == 'metadata_review_needed' ||
        processingStage == 'split_review_needed';

    if (rawUrl.isEmpty) {
      return _ReviewFallbackScaffold(
        title: pieceTitle,
        message: 'This review item does not include a raw score file.',
      );
    }

    if (isMetadataReviewItem || renderedUrl.isEmpty) {
      return _buildMetadataOnlyState(
        context: context,
        item: item,
        pieceTitle: pieceTitle,
        summary: summary,
        provenance: provenance,
        confidence: confidence,
        rawUrl: rawUrl,
        isRawPdf: rawContentType.contains('pdf'),
        processedMetadata: processedMetadata,
        catalogMetadata: catalogMetadata,
        catalogSuggestionFields: catalogSuggestionFields,
        metadataConflicts: metadataConflicts,
        validationWarnings: validationWarnings,
        canonicalUrl: canonicalUrl,
        canonicalScoreVersionId: canonicalScoreVersionId,
        renderedScoreVersionId: renderedScoreVersionId,
        isRenderBlocked: isRenderBlocked,
        renderValidationError: renderValidationError,
      );
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Container(
                  color: theme.colorScheme.surfaceContainerLowest,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        pieceTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text('Status: ${item.status}')),
                          Chip(label: Text('Source: $provenance')),
                          if (confidence != null)
                            Chip(
                                label: Text(
                                    'Confidence ${(confidence * 100).round()}%')),
                        ],
                      ),
                      ..._buildScoreReviewActionWidgets(
                        item: item,
                        canonicalUrl: canonicalUrl,
                        canonicalScoreVersionId: canonicalScoreVersionId,
                        renderedScoreVersionId: renderedScoreVersionId,
                        pieceTitle: pieceTitle,
                        isRenderBlocked: isRenderBlocked,
                        renderValidationError: renderValidationError,
                      ),
                      if (processedMetadata.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _ExtractedMetadataPanel(
                          title: 'Extracted metadata',
                          metadata: processedMetadata,
                        ),
                      ],
                      if (catalogMetadata.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _ExtractedMetadataPanel(
                          title: 'Current catalog metadata',
                          metadata: catalogMetadata,
                        ),
                      ],
                      if (catalogSuggestionFields.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _ExtractedMetadataPanel(
                          title: 'Unapproved metadata suggestions',
                          metadata: catalogSuggestionFields,
                        ),
                      ],
                      if (metadataConflicts.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _MetadataConflictsPanel(conflicts: metadataConflicts),
                      ],
                      if (validationWarnings.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _ReviewWarningsPanel(warnings: validationWarnings),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: theme.colorScheme.surface,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                switch (_compareMode) {
                                  _CompareMode.original =>
                                    'Original source PDF',
                                  _CompareMode.overlay => 'Overlay compare',
                                  _CompareMode.sideBySide =>
                                    'Side-by-side compare',
                                  _CompareMode.processed =>
                                    'Processed candidate',
                                },
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Previous page',
                              onPressed: _currentPage > 1
                                  ? () => _jumpToPage(_currentPage - 1)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text('Page $_currentPage / $_pageCount'),
                            IconButton(
                              tooltip: 'Next page',
                              onPressed: _currentPage < _pageCount
                                  ? () => _jumpToPage(_currentPage + 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: _buildCompareCanvas(
                                rawUrl: rawUrl,
                                renderedUrl: displayedRenderedUrl,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataOnlyState({
    required BuildContext context,
    required ReviewQueueEntry item,
    required String pieceTitle,
    required String summary,
    required String provenance,
    required double? confidence,
    required String rawUrl,
    required bool isRawPdf,
    required Map<String, dynamic> processedMetadata,
    required Map<String, dynamic> catalogMetadata,
    required Map<String, dynamic> catalogSuggestionFields,
    required List<_MetadataConflictData> metadataConflicts,
    required List<String> validationWarnings,
    required String canonicalUrl,
    required String canonicalScoreVersionId,
    required String renderedScoreVersionId,
    required bool isRenderBlocked,
    required String? renderValidationError,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            color: theme.colorScheme.surfaceContainerLowest,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  pieceTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('Status: ${item.status}')),
                    Chip(label: Text('Source: $provenance')),
                    if (confidence != null)
                      Chip(
                        label:
                            Text('Confidence ${(confidence * 100).round()}%'),
                      ),
                  ],
                ),
                if (isRenderBlocked) ...[
                  const SizedBox(height: 16),
                  _RenderBlockedPanel(message: renderValidationError),
                  ..._buildScoreReviewActionWidgets(
                    item: item,
                    canonicalUrl: canonicalUrl,
                    canonicalScoreVersionId: canonicalScoreVersionId,
                    renderedScoreVersionId: renderedScoreVersionId,
                    pieceTitle: pieceTitle,
                    isRenderBlocked: true,
                    renderValidationError: renderValidationError,
                    showCompareControls: false,
                  ),
                ] else
                  ..._buildMetadataReviewActionWidgets(item),
                if (processedMetadata.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ExtractedMetadataPanel(
                    title: 'Extracted metadata',
                    metadata: processedMetadata,
                  ),
                ],
                if (catalogMetadata.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ExtractedMetadataPanel(
                    title: 'Current catalog metadata',
                    metadata: catalogMetadata,
                  ),
                ],
                if (catalogSuggestionFields.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ExtractedMetadataPanel(
                    title: 'Unapproved metadata suggestions',
                    metadata: catalogSuggestionFields,
                  ),
                ],
                if (metadataConflicts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _MetadataConflictsPanel(conflicts: metadataConflicts),
                ],
                if (validationWarnings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ReviewWarningsPanel(warnings: validationWarnings),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.all(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: isRawPdf
                  ? _RemotePdfViewer(
                      url: rawUrl,
                      controller: _rawController,
                      onLoaded: _handleDocumentLoaded,
                      onPageChanged: _handlePageChanged,
                    )
                  : Image.network(
                      rawUrl,
                      headers: _serverRequestHeaders(),
                      fit: BoxFit.contain,
                      errorBuilder: (context, _, __) => SelectableText(
                        'Raw import\n$rawUrl',
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildScoreReviewActionWidgets({
    required ReviewQueueEntry item,
    required String canonicalUrl,
    required String canonicalScoreVersionId,
    required String renderedScoreVersionId,
    required String pieceTitle,
    bool isRenderBlocked = false,
    String? renderValidationError,
    bool showCompareControls = true,
  }) {
    final theme = Theme.of(context);
    final actions = <Widget>[
      if (_isBookReviewItem(item))
        OutlinedButton.icon(
          key: AppKeys.reviewNextButton,
          onPressed: _submitting ? null : _skipToNextReviewItem,
          icon: const Icon(Icons.skip_next_outlined),
          label: const Text('Next'),
        ),
      if (canonicalUrl.isNotEmpty)
        SelectableText(
          'MusicXML candidate\n$canonicalUrl',
          style: theme.textTheme.bodySmall,
        ),
      if (canonicalScoreVersionId.isNotEmpty)
        OutlinedButton.icon(
          key: AppKeys.reviewOpenMuseScoreButton,
          onPressed: _submitting
              ? null
              : () => _openInMuseScore(
                    item,
                    canonicalScoreVersionId,
                    canonicalUrl,
                    pieceTitle,
                  ),
          icon: const Icon(Icons.library_music_outlined),
          label: const Text('Edit in MuseScore'),
        ),
      if (canonicalScoreVersionId.isNotEmpty)
        OutlinedButton.icon(
          key: AppKeys.reviewUploadEditedMusicXmlButton,
          onPressed: _submitting || renderedScoreVersionId.isEmpty
              ? null
              : () => _uploadEditedMusicXml(
                    item,
                    canonicalScoreVersionId,
                    renderedScoreVersionId,
                  ),
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Upload edited MusicXML'),
        ),
      if (canonicalScoreVersionId.isNotEmpty &&
          renderedScoreVersionId.isNotEmpty)
        OutlinedButton.icon(
          onPressed: _submitting
              ? null
              : () => _rerenderScoreVersion(
                    item,
                    canonicalScoreVersionId,
                    renderedScoreVersionId,
                  ),
          icon: const Icon(Icons.refresh_outlined),
          label: Text(
            isRenderBlocked ? 'Retry notation render' : 'Rerender edited PDF',
          ),
        ),
      if (showCompareControls)
        SegmentedButton<_CompareMode>(
          segments: const [
            ButtonSegment(
              value: _CompareMode.original,
              icon: Icon(Icons.picture_as_pdf_outlined),
              label: Text('Original'),
            ),
            ButtonSegment(
              value: _CompareMode.overlay,
              icon: Icon(Icons.layers_outlined),
              label: Text('Overlay'),
            ),
            ButtonSegment(
              value: _CompareMode.sideBySide,
              icon: Icon(Icons.compare_arrows_outlined),
              label: Text('Side by side'),
            ),
            ButtonSegment(
              value: _CompareMode.processed,
              icon: Icon(Icons.auto_fix_high_outlined),
              label: Text('Processed'),
            ),
          ],
          selected: <_CompareMode>{_compareMode},
          onSelectionChanged: (selection) {
            setState(() {
              _compareMode = selection.first;
            });
          },
        ),
      OutlinedButton.icon(
        onPressed: _submitting ? null : () => _editMetadata(item),
        icon: const Icon(Icons.edit_note_outlined),
        label: const Text('Edit metadata'),
      ),
      if (showCompareControls)
        FilledButton.icon(
          key: AppKeys.reviewOverlayToggle,
          onPressed: () {
            setState(() {
              _compareMode = _compareMode == _CompareMode.overlay
                  ? _CompareMode.processed
                  : _CompareMode.overlay;
            });
          },
          icon: const Icon(Icons.layers_outlined),
          label: Text(
            _compareMode == _CompareMode.overlay
                ? 'Hide overlay'
                : 'Show overlay',
          ),
        ),
      if (isRenderBlocked && renderValidationError != null)
        Text(
          renderValidationError,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      FilledButton.icon(
        onPressed:
            _submitting || isRenderBlocked ? null : () => _submitDecision(true),
        icon: const Icon(Icons.verified_outlined),
        label: Text(
          isRenderBlocked
              ? 'Render required before marking ready'
              : (_submitting ? 'Saving...' : 'Mark edit ready'),
        ),
      ),
    ];
    return _spacedReviewActions(actions);
  }

  List<Widget> _buildMetadataReviewActionWidgets(ReviewQueueEntry item) {
    final bulkButton = _bookBulkApprovalButton(
      item,
      processingStage: _metadataReviewStageFor(item),
    );
    final actions = <Widget>[
      if (bulkButton != null) bulkButton,
      if (_isBookReviewItem(item))
        OutlinedButton.icon(
          key: AppKeys.reviewNextButton,
          onPressed: _submitting ? null : _skipToNextReviewItem,
          icon: const Icon(Icons.skip_next_outlined),
          label: const Text('Next'),
        ),
      OutlinedButton.icon(
        onPressed: _submitting ? null : () => _editMetadata(item),
        icon: const Icon(Icons.edit_note_outlined),
        label: const Text('Edit metadata'),
      ),
      OutlinedButton.icon(
        onPressed: _submitting ? null : () => _submitDecision(false),
        icon: const Icon(Icons.close_outlined),
        label: const Text('Reject'),
      ),
      FilledButton.icon(
        onPressed: _submitting ? null : () => _approveMetadataReviewItem(item),
        icon: const Icon(Icons.check_outlined),
        label: Text(_submitting ? 'Approving...' : 'Approve Metadata'),
      ),
    ];
    return _spacedReviewActions(actions);
  }

  Widget? _bookBulkApprovalButton(
    ReviewQueueEntry item, {
    required String processingStage,
  }) {
    final sourceBookId = _metadataText(item.candidateData['source_book_id']);
    final sourceReviewItemId =
        _metadataText(item.candidateData['source_review_item_id']);
    final itemStage = _metadataText(item.candidateData['processing_stage']);
    if ((sourceBookId == null && sourceReviewItemId == null) ||
        itemStage != processingStage) {
      return null;
    }

    final isMetadataStage = _isMetadataReviewStage(processingStage);
    return FilledButton.tonalIcon(
      key: isMetadataStage ? AppKeys.reviewBulkApproveMetadataButton : null,
      onPressed: _submitting
          ? null
          : () => _bulkApproveBookStage(
                item,
                processingStage: processingStage,
              ),
      icon: Icon(
        isMetadataStage
            ? Icons.fact_check_outlined
            : Icons.library_music_outlined,
      ),
      label: Text(
        isMetadataStage
            ? 'Approve all metadata for this book'
            : 'Mark all notation edits ready for this book',
      ),
    );
  }

  List<Widget> _spacedReviewActions(List<Widget> actions) {
    if (actions.isEmpty) {
      return const <Widget>[];
    }
    final spaced = <Widget>[const SizedBox(height: 16)];
    for (var index = 0; index < actions.length; index += 1) {
      if (index > 0) {
        spaced.add(const SizedBox(height: 12));
      }
      spaced.add(actions[index]);
    }
    return spaced;
  }

  Widget _buildCompareCanvas({
    required String rawUrl,
    required String renderedUrl,
  }) {
    switch (_compareMode) {
      case _CompareMode.original:
        return _RemotePdfViewer(
          url: rawUrl,
          controller: _rawController,
          onLoaded: _handleDocumentLoaded,
          onPageChanged: _handlePageChanged,
        );
      case _CompareMode.processed:
        return _RemotePdfViewer(
          url: renderedUrl,
          controller: _candidateController,
          onLoaded: _handleDocumentLoaded,
          onPageChanged: _handlePageChanged,
        );
      case _CompareMode.sideBySide:
        return Row(
          children: [
            Expanded(
              child: _LabeledPdfPane(
                label: 'Original',
                child: _RemotePdfViewer(
                  url: rawUrl,
                  controller: _rawController,
                  onLoaded: _handleDocumentLoaded,
                  onPageChanged: _handlePageChanged,
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _LabeledPdfPane(
                label: 'Processed',
                child: _RemotePdfViewer(
                  url: renderedUrl,
                  controller: _candidateController,
                  onLoaded: _handleDocumentLoaded,
                  onPageChanged: _handlePageChanged,
                ),
              ),
            ),
          ],
        );
      case _CompareMode.overlay:
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: _RemotePdfViewer(
                url: rawUrl,
                controller: _rawController,
                onLoaded: _handleDocumentLoaded,
                onPageChanged: _handlePageChanged,
              ),
            ),
            IgnorePointer(
              child: Opacity(
                opacity: 0.58,
                child: _RemotePdfViewer(
                  url: renderedUrl,
                  controller: _candidateController,
                  onLoaded: _handleDocumentLoaded,
                  onPageChanged: _handlePageChanged,
                ),
              ),
            ),
          ],
        );
    }
  }

  void _handleDocumentLoaded(int pages) {
    if (!mounted) {
      return;
    }
    setState(() {
      _pageCount = pages;
      if (_currentPage > _pageCount) {
        _currentPage = _pageCount;
      }
    });
  }

  void _handlePageChanged(int pageNumber) {
    if (!mounted) {
      return;
    }
    setState(() {
      _currentPage = pageNumber;
    });
    if (_compareMode == _CompareMode.overlay ||
        _compareMode == _CompareMode.sideBySide) {
      _rawController.jumpToPage(pageNumber);
      _candidateController.jumpToPage(pageNumber);
    }
  }

  void _jumpToPage(int pageNumber) {
    _rawController.jumpToPage(pageNumber);
    _candidateController.jumpToPage(pageNumber);
    setState(() {
      _currentPage = pageNumber;
    });
  }

  Future<void> _openInMuseScore(
    ReviewQueueEntry item,
    String canonicalScoreVersionId,
    String canonicalUrl,
    String pieceTitle,
  ) async {
    if (_submitting ||
        canonicalScoreVersionId.isEmpty ||
        canonicalUrl.isEmpty) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final repository = ref.read(serverPieceSyncRepositoryProvider);
      final bytes = await repository.downloadBytes(canonicalUrl);
      if (bytes.isEmpty) {
        throw StateError('Downloaded MusicXML candidate was empty.');
      }
      final editDirectory = await _parentEditDirectory();
      await editDirectory.create(recursive: true);
      final editFile = File(
        path.join(
          editDirectory.path,
          '${_safeFileName(pieceTitle)}-$canonicalScoreVersionId.musicxml',
        ),
      );
      await editFile.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(editFile.path);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Opened a local MusicXML copy. Save or export edits, then return here and upload the edited MusicXML.',
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
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Unable to open the MusicXML candidate: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _uploadEditedMusicXml(
    ReviewQueueEntry item,
    String canonicalScoreVersionId,
    String renderedScoreVersionId,
  ) async {
    if (_submitting ||
        canonicalScoreVersionId.isEmpty ||
        renderedScoreVersionId.isEmpty) {
      return;
    }

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
      _submitting = true;
    });

    try {
      await ref
          .read(serverPieceSyncRepositoryProvider)
          .uploadEditedScoreVersion(
            serverPieceId: item.pieceId,
            canonicalScoreVersionId: canonicalScoreVersionId,
            renderedScoreVersionId: renderedScoreVersionId,
            filePath: editedPath,
          );
      ref.invalidate(reviewItemDetailProvider(item.id));
      refreshParentWorkflowInBackground(
        ref,
        trigger: SyncTrigger.reviewApproval,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _renderRefreshToken += 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rendered PDF refreshed from edited MusicXML.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to upload edited MusicXML: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _rerenderScoreVersion(
    ReviewQueueEntry item,
    String canonicalScoreVersionId,
    String renderedScoreVersionId,
  ) async {
    if (_submitting ||
        canonicalScoreVersionId.isEmpty ||
        renderedScoreVersionId.isEmpty) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await ref.read(serverPieceSyncRepositoryProvider).rerenderScoreVersion(
            serverPieceId: item.pieceId,
            canonicalScoreVersionId: canonicalScoreVersionId,
            renderedScoreVersionId: renderedScoreVersionId,
          );
      ref.invalidate(reviewItemDetailProvider(item.id));
      refreshParentWorkflowInBackground(
        ref,
        trigger: SyncTrigger.reviewApproval,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _renderRefreshToken += 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notation render refreshed.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to rerender MusicXML: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _skipToNextReviewItem() {
    if (_submitting || widget.itemId == null) {
      return;
    }
    final nextReviewItem =
        ref.read(parentReviewQueueProvider.notifier).nextAfterRemoving(
      {widget.itemId!},
      currentItemId: widget.itemId,
    );
    if (!mounted) {
      return;
    }
    if (nextReviewItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No later review items are queued.')),
      );
      return;
    }
    Navigator.of(context).pushReplacementNamed(
      AppRouter.reviewCompare,
      arguments: nextReviewItem.id,
    );
  }

  void _prefetchNextReviewItem(String currentItemId) {
    final nextReviewItem =
        ref.read(parentReviewQueueProvider.notifier).nextAfterRemoving(
      {currentItemId},
      currentItemId: currentItemId,
    );
    if (nextReviewItem == null ||
        _prefetchedReviewItemIds.contains(nextReviewItem.id)) {
      return;
    }
    _prefetchedReviewItemIds.add(nextReviewItem.id);
    unawaited(_prefetchReviewItemDetailAndPdf(nextReviewItem.id));
  }

  Future<void> _prefetchReviewItemDetailAndPdf(String itemId) async {
    try {
      final item = await ref.read(reviewItemDetailProvider(itemId).future);
      final rawUrl = _metadataText(item.candidateData['raw_file_url']);
      if (rawUrl == null || rawUrl.isEmpty || debugUseReviewPdfPlaceholder) {
        return;
      }
      await ref.read(serverPieceSyncRepositoryProvider).downloadBytes(rawUrl);
    } catch (_) {
      // Prefetching is only a latency optimization. The normal screen load remains authoritative.
    }
  }

  void _approveMetadataReviewItem(ReviewQueueEntry item) {
    if (_submitting || widget.itemId == null) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    final repository = ref.read(serverPieceSyncRepositoryProvider);
    final queueNotifier = ref.read(parentReviewQueueProvider.notifier);
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final nextReviewItem = queueNotifier.nextAfterRemoving(
      {item.id},
      currentItemId: item.id,
    );

    queueNotifier.removeItems({item.id});
    ref.invalidate(reviewItemDetailProvider(item.id));
    unawaited(
      _completeOptimisticMetadataApproval(
        repository: repository,
        queueNotifier: queueNotifier,
        container: container,
        messenger: messenger,
        item: item,
      ),
    );

    if (nextReviewItem != null) {
      Navigator.of(context).pushReplacementNamed(
        AppRouter.reviewCompare,
        arguments: nextReviewItem.id,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _completeOptimisticMetadataApproval({
    required ServerPieceSyncRepository repository,
    required ParentReviewQueueNotifier queueNotifier,
    required ProviderContainer container,
    required ScaffoldMessengerState messenger,
    required ReviewQueueEntry item,
  }) async {
    try {
      await repository.approveReviewItem(item.id);
      _refreshParentWorkflowFromContainer(
        container,
        trigger: SyncTrigger.reviewApproval,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Metadata approved.')),
      );
    } catch (error) {
      queueNotifier.restoreItem(item);
      container.invalidate(reviewItemDetailProvider(item.id));
      _refreshParentWorkflowFromContainer(
        container,
        trigger: SyncTrigger.reviewApproval,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to approve metadata: $error')),
      );
    }
  }

  void _refreshParentWorkflowFromContainer(
    ProviderContainer container, {
    required SyncTrigger trigger,
  }) {
    unawaited(
      Future.wait([
        container
            .read(allPiecesProvider.notifier)
            .refreshInBackground(trigger: trigger),
        container
            .read(processingCapabilitiesProvider.notifier)
            .refreshInBackground(),
        container
            .read(parentReviewQueueProvider.notifier)
            .refreshInBackground(),
        container
            .read(parentSyncedPiecesProvider.notifier)
            .refreshInBackground(),
      ]).whenComplete(() {
        container.invalidate(serverHealthProvider);
      }),
    );
  }

  Future<void> _submitDecision(bool approve) async {
    if (_submitting || widget.itemId == null) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final repository = ref.read(serverPieceSyncRepositoryProvider);
      if (approve) {
        final currentItem =
            ref.read(reviewItemDetailProvider(widget.itemId!)).valueOrNull;
        final selectedCandidateId = currentItem == null
            ? _selectedCandidateId
            : _selectedOmrCandidateOption(
                currentItem.candidateData,
                _omrCandidateOptionsFrom(currentItem.candidateData),
                _selectedCandidateId,
              )?.id;
        await repository.approveReviewItem(
          widget.itemId!,
          selectedCandidateId: selectedCandidateId,
        );
      } else {
        await repository.rejectReviewItem(widget.itemId!);
      }
      final queueNotifier = ref.read(parentReviewQueueProvider.notifier);
      final nextReviewItem = queueNotifier.nextAfterRemoving(
        {widget.itemId!},
        currentItemId: widget.itemId,
      );
      queueNotifier.removeItems({widget.itemId!});
      ref.invalidate(reviewItemDetailProvider(widget.itemId!));
      scheduleParentWorkflowRefreshBurst(
        ref,
        trigger: SyncTrigger.reviewApproval,
        isActive: () => mounted,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Notation candidate accepted and cataloged for retraining.'
                : 'Review item rejected.',
          ),
        ),
      );
      if (nextReviewItem != null) {
        Navigator.of(context).pushReplacementNamed(
          AppRouter.reviewCompare,
          arguments: nextReviewItem.id,
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save the review decision: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _bulkApproveBookStage(
    ReviewQueueEntry item, {
    required String processingStage,
  }) async {
    if (_submitting || widget.itemId == null) {
      return;
    }
    final sourceBookId = _metadataText(item.candidateData['source_book_id']);
    final sourceReviewItemId =
        _metadataText(item.candidateData['source_review_item_id']);
    if (sourceBookId == null && sourceReviewItemId == null) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final repository = ref.read(serverPieceSyncRepositoryProvider);
      final result = await repository.approveBookReviewItems(
        sourceBookId: sourceBookId,
        sourceReviewItemId: sourceReviewItemId,
        processingStage: processingStage,
      );
      final resolvedItemIds = result.approvedItemIds.toSet();
      if (resolvedItemIds.isEmpty && result.approvedCount > 0) {
        resolvedItemIds.add(widget.itemId!);
      }
      final queueNotifier = ref.read(parentReviewQueueProvider.notifier);
      final nextReviewItem = queueNotifier.nextAfterRemoving(
        resolvedItemIds,
        currentItemId: widget.itemId,
      );
      queueNotifier.removeItems(resolvedItemIds);
      ref.invalidate(reviewItemDetailProvider(widget.itemId!));
      scheduleParentWorkflowRefreshBurst(
        ref,
        trigger: SyncTrigger.reviewApproval,
        isActive: () => mounted,
      );

      if (!mounted) {
        return;
      }
      final approvedLabel = _isMetadataReviewStage(processingStage)
          ? 'metadata reviews'
          : 'notation edit items';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Approved ${result.approvedCount} $approvedLabel for this book. '
            'Skipped ${result.skippedCount}.',
          ),
        ),
      );

      if (nextReviewItem != null) {
        Navigator.of(context).pushReplacementNamed(
          AppRouter.reviewCompare,
          arguments: nextReviewItem.id,
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to approve book reviews: $error')),
      );
    }
  }

  Future<void> _editMetadata(ReviewQueueEntry item) async {
    final draft = await showDialog<_ReviewMetadataDraft>(
      context: context,
      builder: (context) => _ReviewMetadataDialog(
        seed: _ReviewMetadataSeed.fromReviewItem(item),
      ),
    );
    if (draft == null || !mounted) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await ref.read(allPiecesProvider.notifier).updateRemoteMetadata(
            serverPieceId: item.pieceId,
            title: draft.title,
            composer: draft.composer,
            primaryInstrument: draft.primaryInstrument,
            bookOrCollection: draft.bookOrCollection,
            keySignature: draft.keySignature,
            tempo: draft.tempo,
            notes: draft.notes,
            aliases: draft.aliases,
            sourcePageStart: draft.sourcePageStart,
            sourcePageEnd: draft.sourcePageEnd,
          );
      ref.invalidate(reviewItemDetailProvider(item.id));
      refreshParentWorkflowInBackground(
        ref,
        trigger: SyncTrigger.reviewApproval,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated metadata for ${draft.title}.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save metadata: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}

class _OmrCandidateOption {
  const _OmrCandidateOption(this.data);

  final Map<String, dynamic> data;

  String get id => _metadataText(data['candidate_id']) ?? '';

  String get label {
    final explicit = _metadataText(data['label']);
    if (explicit != null) {
      return explicit;
    }
    final engine = _metadataText(data['engine_name']) ?? 'OMR';
    final profile = _metadataText(data['profile']);
    return profile == null ? engine : '$engine $profile';
  }

  String? get engineName => _metadataText(data['engine_name']);

  String? get profile => _metadataText(data['profile']);

  String? get renderStatus => _metadataText(data['render_validation_status']);

  String? get renderedScoreVersionId => _metadataText(data['score_version_id']);

  String get renderedUrl => _metadataText(data['rendered_file_url']) ?? '';

  double? get qualityScore => (data['omr_quality_score'] as num?)?.toDouble();

  bool get selected => data['selected'] == true;
}

List<_OmrCandidateOption> _omrCandidateOptionsFrom(
  Map<String, dynamic> candidateData,
) {
  final options = _metadataListFrom(candidateData['omr_candidates'])
      .map(_OmrCandidateOption.new)
      .where((option) => option.id.isNotEmpty)
      .toList(growable: false);
  final topLevelOptionData = _topLevelOmrCandidateOptionData(candidateData);
  if (topLevelOptionData == null) {
    return options;
  }

  final topLevelOption = _OmrCandidateOption(topLevelOptionData);
  final alreadyIncluded = options.any(
    (option) =>
        option.id == topLevelOption.id ||
        _metadataText(option.data['score_version_id']) ==
            topLevelOption.renderedScoreVersionId,
  );
  if (alreadyIncluded) {
    return options;
  }
  return [topLevelOption, ...options];
}

Map<String, dynamic>? _topLevelOmrCandidateOptionData(
  Map<String, dynamic> candidateData,
) {
  final renderedScoreVersionId =
      _metadataText(candidateData['score_version_id']);
  final renderedUrl = _metadataText(candidateData['rendered_file_url']);
  final canonicalScoreVersionId =
      _metadataText(candidateData['canonical_score_version_id']);
  final canonicalUrl = _metadataText(candidateData['canonical_file_url']);
  if ((renderedScoreVersionId == null || renderedUrl == null) &&
      (canonicalScoreVersionId == null || canonicalUrl == null)) {
    return null;
  }

  final candidateId = _metadataText(candidateData['candidate_id']) ??
      _metadataText(candidateData['selected_omr_candidate_id']) ??
      renderedScoreVersionId ??
      canonicalScoreVersionId;
  if (candidateId == null) {
    return null;
  }

  final engineName = _metadataText(candidateData['engine_name']) ?? 'OMR';
  return <String, dynamic>{
    'candidate_id': candidateId,
    'label': 'Current $engineName candidate',
    'engine_name': engineName,
    'engine_version': candidateData['engine_version'],
    'profile': candidateData['profile'],
    'provenance': candidateData['provenance'],
    'confidence': candidateData['confidence'],
    'processed_metadata': candidateData['processed_metadata'],
    'musicxml_metadata': candidateData['musicxml_metadata'],
    'raw_score_version_id': candidateData['raw_score_version_id'],
    'raw_file_url': candidateData['raw_file_url'],
    'raw_content_type': candidateData['raw_content_type'],
    'score_version_id': renderedScoreVersionId,
    'rendered_file_url': renderedUrl,
    'canonical_score_version_id': canonicalScoreVersionId,
    'canonical_file_url': canonicalUrl,
    'render_validation_status': candidateData['render_validation_status'],
    'render_validation_error': candidateData['render_validation_error'],
    'omr_quality_score': candidateData['omr_quality_score'],
    'warnings': candidateData['warnings'],
    'selected': true,
  };
}

_OmrCandidateOption? _selectedOmrCandidateOption(
  Map<String, dynamic> candidateData,
  List<_OmrCandidateOption> options,
  String? preferredCandidateId,
) {
  if (options.isEmpty) {
    return null;
  }
  final preferred = preferredCandidateId?.trim();
  if (preferred != null && preferred.isNotEmpty) {
    for (final option in options) {
      if (option.id == preferred) {
        return option;
      }
    }
  }
  final serverSelected =
      _metadataText(candidateData['selected_omr_candidate_id']);
  if (serverSelected != null) {
    for (final option in options) {
      if (option.id == serverSelected) {
        return option;
      }
    }
  }
  for (final option in options) {
    if (option.selected) {
      return option;
    }
  }
  return options.first;
}

Map<String, dynamic> _activeCandidateData(
  Map<String, dynamic> baseCandidateData,
  _OmrCandidateOption? selectedCandidate,
) {
  if (selectedCandidate == null) {
    return baseCandidateData;
  }
  final output = Map<String, dynamic>.from(baseCandidateData)
    ..addAll(selectedCandidate.data);

  for (final key in _latestLlmAttemptKeys) {
    if (baseCandidateData.containsKey(key)) {
      output[key] = baseCandidateData[key];
    }
  }

  for (final key in [
    'raw_file_url',
    'raw_content_type',
    'source_book_id',
    'source_review_item_id',
    'processing_stage',
    'catalog_metadata',
    'catalog_suggestions',
    'validation_warnings',
    'contained_piece_titles',
    'multi_piece_page',
  ]) {
    output[key] ??= baseCandidateData[key];
  }

  final warnings = {
    ..._stringListFrom(baseCandidateData['warnings']),
    ..._stringListFrom(selectedCandidate.data['warnings']),
  }.toList(growable: false);
  if (warnings.isNotEmpty) {
    output['warnings'] = warnings;
  }
  output['selected_omr_candidate_id'] = selectedCandidate.id;
  return output;
}

const _latestLlmAttemptKeys = [
  'llm_review_status',
  'llm_notation_review_status',
  'llm_review_provider',
  'llm_review_job_id',
  'llm_review_summary',
  'llm_audit_summary',
  'llm_notation_findings',
  'llm_tool_results',
  'llm_model',
  'llm_vision_model_hint',
  'llm_model_auto_selected',
  'llm_retry_attempted',
  'llm_correction_scope',
  'llm_visual_diff',
];

class _ReviewMetadataSeed {
  const _ReviewMetadataSeed({
    required this.title,
    this.composer,
    this.primaryInstrument,
    this.bookOrCollection,
    this.keySignature,
    this.tempo,
    this.notes,
    this.aliases = const <String>[],
    this.sourcePageStart,
    this.sourcePageEnd,
  });

  final String title;
  final String? composer;
  final String? primaryInstrument;
  final String? bookOrCollection;
  final String? keySignature;
  final String? tempo;
  final String? notes;
  final List<String> aliases;
  final int? sourcePageStart;
  final int? sourcePageEnd;

  factory _ReviewMetadataSeed.fromReviewItem(ReviewQueueEntry item) {
    final candidateData = item.candidateData;
    final catalogMetadata = _metadataMapFrom(candidateData['catalog_metadata']);
    final processedMetadata =
        _metadataMapFrom(candidateData['processed_metadata']);
    return _ReviewMetadataSeed(
      title: _metadataText(catalogMetadata['title']) ??
          _metadataText(processedMetadata['title']) ??
          (candidateData['piece_title'] as String?) ??
          item.title,
      composer: _metadataText(catalogMetadata['composer']) ??
          _metadataText(processedMetadata['composer']),
      primaryInstrument: _metadataText(catalogMetadata['primary_instrument']) ??
          _metadataText(processedMetadata['primary_instrument']),
      bookOrCollection: _metadataText(catalogMetadata['book_or_collection']) ??
          _metadataText(processedMetadata['book_or_collection']),
      keySignature: _metadataText(catalogMetadata['key_signature']) ??
          _metadataText(processedMetadata['key_signature']),
      tempo: _metadataText(catalogMetadata['tempo']) ??
          _metadataText(processedMetadata['tempo']),
      notes: _metadataText(catalogMetadata['notes']),
      aliases: _aliasesFrom(catalogMetadata['aliases']),
      sourcePageStart: _metadataInt(catalogMetadata['source_page_start']) ??
          _metadataInt(candidateData['source_page_start']),
      sourcePageEnd: _metadataInt(catalogMetadata['source_page_end']) ??
          _metadataInt(candidateData['source_page_end']),
    );
  }
}

class _ReviewMetadataDraft {
  const _ReviewMetadataDraft({
    required this.title,
    this.composer,
    this.primaryInstrument,
    this.bookOrCollection,
    this.keySignature,
    this.tempo,
    this.notes,
    this.aliases = const <String>[],
    this.sourcePageStart,
    this.sourcePageEnd,
  });

  final String title;
  final String? composer;
  final String? primaryInstrument;
  final String? bookOrCollection;
  final String? keySignature;
  final String? tempo;
  final String? notes;
  final List<String> aliases;
  final int? sourcePageStart;
  final int? sourcePageEnd;
}

class _ReviewMetadataDialog extends StatefulWidget {
  const _ReviewMetadataDialog({required this.seed});

  final _ReviewMetadataSeed seed;

  @override
  State<_ReviewMetadataDialog> createState() => _ReviewMetadataDialogState();
}

class _ReviewMetadataDialogState extends State<_ReviewMetadataDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _composerController;
  late final TextEditingController _instrumentController;
  late final TextEditingController _bookController;
  late final TextEditingController _keyController;
  late final TextEditingController _tempoController;
  late final TextEditingController _aliasesController;
  late final TextEditingController _startPageController;
  late final TextEditingController _endPageController;
  late final TextEditingController _notesController;

  String? _titleError;

  @override
  void initState() {
    super.initState();
    final seed = widget.seed;
    _titleController = TextEditingController(text: seed.title);
    _composerController = TextEditingController(text: seed.composer ?? '');
    _instrumentController =
        TextEditingController(text: seed.primaryInstrument ?? '');
    _bookController = TextEditingController(text: seed.bookOrCollection ?? '');
    _keyController = TextEditingController(text: seed.keySignature ?? '');
    _tempoController = TextEditingController(text: seed.tempo ?? '');
    _aliasesController = TextEditingController(text: seed.aliases.join(', '));
    _startPageController =
        TextEditingController(text: seed.sourcePageStart?.toString() ?? '');
    _endPageController =
        TextEditingController(text: seed.sourcePageEnd?.toString() ?? '');
    _notesController = TextEditingController(text: seed.notes ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _composerController.dispose();
    _instrumentController.dispose();
    _bookController.dispose();
    _keyController.dispose();
    _tempoController.dispose();
    _aliasesController.dispose();
    _startPageController.dispose();
    _endPageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit review metadata'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  errorText: _titleError,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _composerController,
                decoration: const InputDecoration(
                  labelText: 'Composer',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _instrumentController,
                      decoration: const InputDecoration(
                        labelText: 'Instrument',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _bookController,
                      decoration: const InputDecoration(
                        labelText: 'Book / collection',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keyController,
                      decoration: const InputDecoration(
                        labelText: 'Key',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _tempoController,
                      decoration: const InputDecoration(
                        labelText: 'Tempo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _aliasesController,
                decoration: const InputDecoration(
                  labelText: 'Alternate titles',
                  helperText: 'Separate aliases with commas.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _startPageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Source page start',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _endPageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Source page end',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Parent notes',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save metadata'),
        ),
      ],
    );
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _titleError = 'Title is required.';
      });
      return;
    }

    Navigator.of(context).pop(
      _ReviewMetadataDraft(
        title: title,
        composer: _optionalText(_composerController.text),
        primaryInstrument: _optionalText(_instrumentController.text),
        bookOrCollection: _optionalText(_bookController.text),
        keySignature: _optionalText(_keyController.text),
        tempo: _optionalText(_tempoController.text),
        notes: _optionalText(_notesController.text),
        aliases: _aliasesController.text
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
        sourcePageStart: _optionalInt(_startPageController.text),
        sourcePageEnd: _optionalInt(_endPageController.text),
      ),
    );
  }
}

class _ExtractedMetadataPanel extends StatelessWidget {
  const _ExtractedMetadataPanel({
    required this.title,
    required this.metadata,
  });

  final String title;
  final Map<String, dynamic> metadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <_MetadataRowData>[
      _MetadataRowData('Detected title', _metadataText(metadata['title'])),
      _MetadataRowData('Composer', _metadataText(metadata['composer'])),
      _MetadataRowData(
          'Instrument', _metadataText(metadata['primary_instrument'])),
      _MetadataRowData('Key', _metadataText(metadata['key_signature'])),
      _MetadataRowData('Time', _metadataText(metadata['time_signature'])),
      _MetadataRowData('Tempo', _metadataText(metadata['tempo'])),
      _MetadataRowData('Measures', _metadataText(metadata['measure_count'])),
      _MetadataRowData('Parts', _metadataText(metadata['part_count'])),
    ].where((row) => row.value != null && row.value!.isNotEmpty).toList();

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        row.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewWarningsPanel extends StatelessWidget {
  const _ReviewWarningsPanel({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: theme.colorScheme.error.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review warnings',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...warnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  warning,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataConflictsPanel extends StatelessWidget {
  const _MetadataConflictsPanel({required this.conflicts});

  final List<_MetadataConflictData> conflicts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.36),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Metadata conflicts',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Suggestions below disagree with the current editable metadata. They are advisory and are not applied automatically.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ...conflicts.map(
              (conflict) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${conflict.label}: current "${conflict.currentValue}", suggested "${conflict.suggestedValue}" (${conflict.source})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataRowData {
  const _MetadataRowData(this.label, this.value);

  final String label;
  final String? value;
}

class _MetadataConflictData {
  const _MetadataConflictData({
    required this.label,
    required this.currentValue,
    required this.suggestedValue,
    required this.source,
  });

  final String label;
  final String currentValue;
  final String suggestedValue;
  final String source;
}

class _LabeledPdfPane extends StatelessWidget {
  const _LabeledPdfPane({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: theme.colorScheme.surfaceContainerLow,
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _RemotePdfViewer extends StatelessWidget {
  const _RemotePdfViewer({
    required this.url,
    required this.controller,
    required this.onLoaded,
    required this.onPageChanged,
  });

  final String url;
  final PdfViewerController controller;
  final ValueChanged<int> onLoaded;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (debugUseReviewPdfPlaceholder) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: Center(
          child: Text(
            'PDF preview\n$url',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SfPdfViewer.network(
      url,
      key: ValueKey<String>(url),
      headers: _serverRequestHeaders(),
      controller: controller,
      pageLayoutMode: PdfPageLayoutMode.single,
      scrollDirection: PdfScrollDirection.horizontal,
      canShowPaginationDialog: false,
      canShowScrollHead: false,
      canShowScrollStatus: false,
      onDocumentLoaded: (details) {
        onLoaded(details.document.pages.count);
      },
      onPageChanged: (details) {
        onPageChanged(details.newPageNumber);
      },
      onDocumentLoadFailed: (details) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to load PDF: ${details.error}. ${details.description}',
            ),
          ),
        );
      },
    );
  }
}

Map<String, String> _serverRequestHeaders() {
  final token = AppConfig.serverPairingToken;
  if (token == null || token.isEmpty) {
    return const <String, String>{};
  }
  return <String, String>{
    'X-AZMusic-Device-Token': token,
  };
}

class _RenderBlockedPanel extends StatelessWidget {
  const _RenderBlockedPanel({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.picture_as_pdf_outlined,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Notation render needs attention',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message ??
                  'MusicXML was generated, but the review PDF was not usable. '
                      'Retry the render after confirming MuseScore Studio is installed.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewFallbackScaffold extends StatelessWidget {
  const _ReviewFallbackScaffold({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.reviewCompareScreen,
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

String _cacheBustedUrl(String url, int token) {
  if (url.isEmpty || token <= 0) {
    return url;
  }
  final separator = url.contains('?') ? '&' : '?';
  return '$url${separator}v=$token';
}

Future<Directory> _parentEditDirectory() async {
  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return Directory(path.join(downloads.path, 'AZMusic Edits'));
    }
  } catch (_) {
    // Mobile platforms may not expose a downloads directory consistently.
  }
  final documents = await getApplicationDocumentsDirectory();
  return Directory(path.join(documents.path, 'AZMusic Edits'));
}

String _safeFileName(String value) {
  final cleaned = value
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9._ -]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
  final withoutDots = cleaned.replaceAll(RegExp(r'^\.+'), '').trim();
  if (withoutDots.isEmpty) {
    return 'azmusic-candidate';
  }
  return withoutDots.length > 80 ? withoutDots.substring(0, 80) : withoutDots;
}

Map<String, dynamic> _metadataMapFrom(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

bool _isBookReviewItem(ReviewQueueEntry item) {
  final candidateData = item.candidateData;
  return _metadataText(candidateData['source_book_id']) != null ||
      _metadataText(candidateData['source_review_item_id']) != null ||
      _metadataText(candidateData['book_or_collection']) != null ||
      _metadataText(
            _metadataMapFrom(
                candidateData['catalog_metadata'])['book_or_collection'],
          ) !=
          null;
}

String _metadataReviewStageFor(ReviewQueueEntry item) {
  final stage = _metadataText(item.candidateData['processing_stage']);
  if (stage == 'metadata_review_needed' || stage == 'split_review_needed') {
    return stage!;
  }
  return _isBookReviewItem(item)
      ? 'split_review_needed'
      : 'metadata_review_needed';
}

bool _isMetadataReviewStage(String stage) {
  return stage == 'metadata_review_needed' || stage == 'split_review_needed';
}

List<Map<String, dynamic>> _metadataListFrom(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return const <Map<String, dynamic>>[];
}

List<String> _stringListFrom(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
  return const <String>[];
}

Map<String, dynamic> _firstSuggestionFields(
  List<Map<String, dynamic>> suggestions,
) {
  for (final suggestion in suggestions) {
    final fields = suggestion['fields'];
    if (fields is Map) {
      final output = Map<String, dynamic>.from(fields);
      final source = _metadataText(suggestion['source']);
      final confidence = (suggestion['confidence'] as num?)?.toDouble();
      if (source != null) {
        output['suggestion_source'] = source;
      }
      if (confidence != null) {
        output['suggestion_confidence'] = '${(confidence * 100).round()}%';
      }
      return output;
    }
  }
  return const <String, dynamic>{};
}

List<_MetadataConflictData> _metadataConflicts({
  required Map<String, dynamic> currentMetadata,
  required List<Map<String, dynamic>> suggestions,
}) {
  const fields = <String, String>{
    'title': 'Title',
    'composer': 'Composer',
    'primary_instrument': 'Instrument',
    'book_or_collection': 'Book',
    'source_page_start': 'Start page',
    'source_page_end': 'End page',
    'key_signature': 'Key',
    'tempo': 'Tempo',
  };
  final conflicts = <_MetadataConflictData>[];
  for (final suggestion in suggestions) {
    final suggestionFields = suggestion['fields'];
    if (suggestionFields is! Map) {
      continue;
    }
    final source = _metadataText(suggestion['source']) ?? 'suggestion';
    for (final entry in fields.entries) {
      final currentValue = _metadataText(currentMetadata[entry.key]);
      final suggestedValue = _metadataText(suggestionFields[entry.key]);
      if (currentValue == null || suggestedValue == null) {
        continue;
      }
      if (_metadataComparable(currentValue) ==
          _metadataComparable(suggestedValue)) {
        continue;
      }
      conflicts.add(
        _MetadataConflictData(
          label: entry.value,
          currentValue: currentValue,
          suggestedValue: suggestedValue,
          source: source,
        ),
      );
    }
  }
  return conflicts;
}

String _metadataComparable(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

String? _metadataText(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Iterable) {
    final joined = value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .join(', ');
    return joined.isEmpty ? null : joined;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String? _optionalText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _optionalInt(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return int.tryParse(trimmed);
}

int? _metadataInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

List<String> _aliasesFrom(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}
