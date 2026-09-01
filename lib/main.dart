import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/dependencies_repo.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DependenciesRepo.register();
  // Read before the first frame, so the app opens in the theme and the
  // ordering it was left in rather than flashing the defaults and correcting
  // itself a frame later.
  await GetIt.I.get<SettingsRepo>().load();
  // The ticker directory and the figures both live in the database, which the
  // gate in front of the app loads — or offers to populate — on first frame.
  runApp(const PickStockApp());
}
