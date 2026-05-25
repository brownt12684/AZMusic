import 'app/launch_options.dart';
import 'bootstrap.dart';

Future<void> main() async {
  await bootstrapApp(AppLaunchOptions.sandbox());
}
