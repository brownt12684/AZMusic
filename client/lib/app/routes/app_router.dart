import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../presentation/screens/login/login_screen.dart';
import '../../presentation/screens/library/library_screen.dart';
import '../../presentation/screens/parent/processing_settings_screen.dart';
import '../../presentation/screens/sandbox/sandbox_launcher_screen.dart';
import '../../presentation/screens/shell/teacher_shell_screen.dart';
import '../../presentation/screens/piece_detail/piece_detail_screen.dart';

class AppRouter {
  AppRouter._();

  static const String login = '/';
  static const String library = '/library';
  static const String parentHome = '/parent-home';
  static const String parentProcessingSettings = '/parent-processing-settings';
  static const String sandbox = '/sandbox';
  static const String pieceDetail = '/piece-detail';
  static const String reader = '/reader';
  static const String reviewQueue = '/review-queue';
  static const String reviewCompare = '/review-compare';

  static Map<String, WidgetBuilder> get routes {
    final routes = <String, WidgetBuilder>{
      login: (context) => const LoginScreen(),
      library: (context) => const LibraryScreen(),
      parentHome: (context) => const TeacherShellScreen(),
      parentProcessingSettings: (context) => const ProcessingSettingsScreen(),
      reviewQueue: (context) => const TeacherShellScreen(),
      pieceDetail: (context) => PieceDetailScreen(
        pieceId: ModalRoute.of(context)?.settings.arguments as String?,
      ),
    };
    if (!AppConfig.isProductionBuild) {
      routes[sandbox] = (context) => const SandboxLauncherScreen();
    }
    return routes;
  }

  static String? notFoundRoute(String? route) {
    return login;
  }
}
