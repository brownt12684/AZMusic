import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/launch_options.dart';
import 'core/config/app_config.dart';
import 'injection/container.dart';

Future<void> bootstrapApp(AppLaunchOptions launchOptions) async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.white,
  ));

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final appDir = await getApplicationDocumentsDirectory();
  await AppConfig.initialize();

  runApp(
    ProviderScope(
      overrides: [
        appDirectoryProvider.overrideWith((ref) => appDir),
        launchOptionsProvider.overrideWith((ref) => launchOptions),
      ],
      child: const AzMusicApp(),
    ),
  );
}
