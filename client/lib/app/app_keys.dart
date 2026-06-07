import 'package:flutter/widgets.dart';

class AppKeys {
  AppKeys._();

  static const loginScreen = ValueKey<String>('login.screen');
  static const parentHomeScreen = ValueKey<String>('parentHome.screen');
  static const parentServerStatus = ValueKey<String>('parent.serverStatus');
  static const parentProcessingSettingsScreen =
      ValueKey<String>('parent.processingSettings.screen');
  static const parentProcessingSettingsButton =
      ValueKey<String>('parent.processingSettings.open');
  static const parentPairingQr = ValueKey<String>('parent.pairing.qr');
  static const parentPairingRefreshButton =
      ValueKey<String>('parent.pairing.refresh');
  static const advancedProcessingSettingsToggle =
      ValueKey<String>('parent.processingSettings.advanced');
  static const libraryScreen = ValueKey<String>('library.screen');
  static const libraryStatusBanner = ValueKey<String>('library.statusBanner');
  static const libraryEmptyState = ValueKey<String>('library.emptyState');
  static const libraryList = ValueKey<String>('library.list');
  static const librarySearchField = ValueKey<String>('library.search');
  static const parentImportButton = ValueKey<String>('parent.importScore');
  static const parentDebugToolsToggle =
      ValueKey<String>('parent.debugTools.toggle');
  static const parentDebugToolsCard =
      ValueKey<String>('parent.debugTools.card');
  static const parentDebugClearLibrariesButton =
      ValueKey<String>('parent.debugTools.clearLibraries');
  static const parentDebugRefreshJobsButton =
      ValueKey<String>('parent.debugTools.refreshJobs');
  static const parentWorkflowList = ValueKey<String>('parent.workflowList');
  static const parentIntakeList = ValueKey<String>('parent.intakeList');
  static const parentServerReadyList =
      ValueKey<String>('parent.serverReadyList');
  static const parentAddStudentButton = ValueKey<String>('parent.student.add');
  static const parentStudentNameField = ValueKey<String>('parent.student.name');
  static const parentCreateStudentButton =
      ValueKey<String>('parent.student.create');
  static const parentPinEntryField = ValueKey<String>('parent.pin.entry');
  static const parentPinSetupField = ValueKey<String>('parent.pin.setup');
  static const parentPinConfirmField = ValueKey<String>('parent.pin.confirm');
  static const parentPinCreateButton = ValueKey<String>('parent.pin.create');
  static const logoutButton = ValueKey<String>('app.logout');
  static const reviewQueueButton = ValueKey<String>('library.reviewQueue');
  static const pieceDetailScreen = ValueKey<String>('pieceDetail.screen');
  static const readerScreen = ValueKey<String>('reader.screen');
  static const reviewQueueScreen = ValueKey<String>('reviewQueue.screen');
  static const reviewCompareScreen = ValueKey<String>('reviewCompare.screen');
  static const sandboxLauncherScreen = ValueKey<String>('sandbox.screen');
  static const sandboxResetLibraryButton = ValueKey<String>('sandbox.reset');
  static const sandboxOpenLibraryButton =
      ValueKey<String>('sandbox.openLibrary');
  static const sandboxOpenPieceDetailButton =
      ValueKey<String>('sandbox.openPieceDetail');
  static const sandboxOpenReaderButton = ValueKey<String>('sandbox.openReader');
  static const sandboxOpenReviewQueueButton =
      ValueKey<String>('sandbox.openReviewQueue');
  static const aboutModuleButton = ValueKey<String>('reader.module.about');
  static const mediaModuleButton = ValueKey<String>('reader.module.media');
  static const tunerModuleButton = ValueKey<String>('reader.module.tuner');
  static const notesModuleButton = ValueKey<String>('reader.module.notes');
  static const notesLayerVisibilityToggle = ValueKey<String>(
    'reader.notes.layerVisibility',
  );
  static const notesDrawModeToggle = ValueKey<String>(
    'reader.notes.drawMode',
  );
  static const notesClearPageButton = ValueKey<String>(
    'reader.notes.clearPage',
  );
  static const notesComposerField = ValueKey<String>('reader.notes.composer');
  static const reviewOverlayToggle =
      ValueKey<String>('reviewCompare.overlayToggle');
  static const reviewOpenMuseScoreButton =
      ValueKey<String>('reviewCompare.openMuseScore');
  static const reviewRefreshRenderedPdfButton =
      ValueKey<String>('reviewCompare.refreshRenderedPdf');
  static const reviewUploadEditedMusicXmlButton =
      ValueKey<String>('reviewCompare.uploadEditedMusicXml');
  static const reviewAiScoreReviewButton =
      ValueKey<String>('reviewCompare.aiScoreReview');
  static const reviewNextButton = ValueKey<String>('reviewCompare.next');
  static const reviewBulkApproveMetadataButton =
      ValueKey<String>('reviewCompare.bulkApproveMetadata');
  static const reviewBulkApproveMuseScoreButton =
      ValueKey<String>('reviewCompare.bulkApproveMuseScore');
  static const parentReviewCard = ValueKey<String>('parent.reviewCard');

  static ValueKey<String> pieceCard(String pieceId) {
    return ValueKey<String>('library.pieceCard.$pieceId');
  }

  static ValueKey<String> libraryTab(String tabId) {
    return ValueKey<String>('library.tab.$tabId');
  }

  static ValueKey<String> alphaJump(String letter) {
    return ValueKey<String>('library.alpha.$letter');
  }

  static ValueKey<String> openScoreButton(String scoreVersionId) {
    return ValueKey<String>('pieceDetail.openScore.$scoreVersionId');
  }

  static ValueKey<String> profileButton(String profileId) {
    return ValueKey<String>('login.profile.$profileId');
  }

  static ValueKey<String> pushToProfileButton(
      String pieceId, String profileId) {
    return ValueKey<String>('parent.push.$pieceId.$profileId');
  }

  static ValueKey<String> studentDevicePairingButton(String profileId) {
    return ValueKey<String>('parent.studentDevicePair.$profileId');
  }

  static ValueKey<String> noteCard(String noteId) {
    return ValueKey<String>('reader.note.$noteId');
  }

  static ValueKey<String> reviewQueueItem(String itemId) {
    return ValueKey<String>('parent.review.$itemId');
  }

  static ValueKey<String> parentDebugCancelJobButton(String jobId) {
    return ValueKey<String>('parent.debugTools.cancelJob.$jobId');
  }

  static ValueKey<String> parentDebugRetryJobButton(String jobId) {
    return ValueKey<String>('parent.debugTools.retryJob.$jobId');
  }
}
