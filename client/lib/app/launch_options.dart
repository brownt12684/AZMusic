import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLaunchSurface {
  login,
  library,
  parentHome,
  sandbox,
  pieceDetail,
  reader,
  reviewQueue,
}

class AppLaunchOptions {
  const AppLaunchOptions({
    required this.sandboxMode,
    required this.resetLibraryOnLaunch,
    required this.initialSurface,
  });

  final bool sandboxMode;
  final bool resetLibraryOnLaunch;
  final AppLaunchSurface initialSurface;

  bool get useSandboxLauncher =>
      sandboxMode || initialSurface == AppLaunchSurface.sandbox;

  String get surfaceLabel => switch (initialSurface) {
        AppLaunchSurface.login => 'Login',
        AppLaunchSurface.library => 'Library',
        AppLaunchSurface.parentHome => 'Parent home',
        AppLaunchSurface.sandbox => 'Sandbox launcher',
        AppLaunchSurface.pieceDetail => 'Piece detail',
        AppLaunchSurface.reader => 'Reader',
        AppLaunchSurface.reviewQueue => 'Review queue',
      };

  static const bool _resetSandboxFlag = bool.fromEnvironment(
    'AZMUSIC_RESET_SANDBOX_ON_LAUNCH',
  );
  static const String _sandboxSurfaceFlag = String.fromEnvironment(
    'AZMUSIC_SANDBOX_SURFACE',
    defaultValue: 'sandbox',
  );

  factory AppLaunchOptions.standard() {
    return const AppLaunchOptions(
      sandboxMode: false,
      resetLibraryOnLaunch: false,
      initialSurface: AppLaunchSurface.login,
    );
  }

  factory AppLaunchOptions.sandbox() {
    return AppLaunchOptions(
      sandboxMode: true,
      resetLibraryOnLaunch: _resetSandboxFlag,
      initialSurface: _parseSurface(_sandboxSurfaceFlag),
    );
  }

  static AppLaunchSurface _parseSurface(String value) {
    switch (value.trim().toLowerCase()) {
      case 'library':
        return AppLaunchSurface.library;
      case 'login':
        return AppLaunchSurface.login;
      case 'parent-home':
      case 'parent_home':
      case 'parent':
        return AppLaunchSurface.parentHome;
      case 'piece-detail':
      case 'piece_detail':
      case 'piece':
        return AppLaunchSurface.pieceDetail;
      case 'reader':
        return AppLaunchSurface.reader;
      case 'review-queue':
      case 'review_queue':
      case 'review':
        return AppLaunchSurface.reviewQueue;
      case 'sandbox':
      default:
        return AppLaunchSurface.sandbox;
    }
  }
}

final launchOptionsProvider = Provider<AppLaunchOptions>(
  (ref) => AppLaunchOptions.standard(),
);
