import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import 'launch_options.dart';
import '../presentation/screens/parent/review_compare_screen.dart';
import '../presentation/screens/piece_detail/piece_detail_screen.dart';
import '../presentation/screens/reader/reader_screen.dart';
import 'routes/app_router.dart';
import 'sync_boundary.dart';
import 'theme/app_theme.dart';

class AzMusicApp extends ConsumerWidget {
  const AzMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final launchOptions = ref.watch(launchOptionsProvider);
    final initialRoute = switch (launchOptions.initialSurface) {
      AppLaunchSurface.login => AppRouter.login,
      AppLaunchSurface.library when !launchOptions.resetLibraryOnLaunch =>
        AppRouter.library,
      AppLaunchSurface.parentHome => AppRouter.parentHome,
      AppLaunchSurface.reviewQueue when !launchOptions.resetLibraryOnLaunch =>
        AppRouter.reviewQueue,
      AppLaunchSurface.sandbox when !AppConfig.isProductionBuild =>
        AppRouter.sandbox,
      _ when launchOptions.useSandboxLauncher && !AppConfig.isProductionBuild =>
        AppRouter.sandbox,
      _ => AppRouter.login,
    };

    return SyncBoundary(
      child: MaterialApp(
        title: 'AZMusic',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        initialRoute: initialRoute,
        routes: AppRouter.routes,
        onGenerateRoute: (settings) {
          // Handle dynamic routes with arguments
          switch (settings.name) {
            case AppRouter.pieceDetail:
              final pieceId = settings.arguments as String?;
              return MaterialPageRoute(
                builder: (_) => PieceDetailScreen(pieceId: pieceId),
              );
            case AppRouter.reader:
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (_) => ReaderScreen(
                  pieceId: args?['pieceId'] as String?,
                  scoreVersionId: args?['scoreVersionId'] as String?,
                ),
              );
            case AppRouter.reviewCompare:
              final itemId = settings.arguments as String?;
              return MaterialPageRoute(
                builder: (_) => ReviewCompareScreen(itemId: itemId),
              );
            default:
              return MaterialPageRoute(
                builder: (_) => Scaffold(
                  body: Center(child: Text('Page not found: ${settings.name}')),
                ),
              );
          }
        },
      ),
    );
  }
}
