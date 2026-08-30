import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/dependencies_repo.dart';
import 'package:pickstock/repo/sec/ticker_directory_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DependenciesRepo.register();
  // Parsed up front so the first lookup is a map read rather than a download.
  await GetIt.I.get<TickerDirectoryRepo>().load();
  runApp(const PickStockApp());
}
