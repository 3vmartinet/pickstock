import 'package:pickstock/app.dart';
import 'package:pickstock/repo/dependencies_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  DependenciesRepo.register();
  // The ticker directory and the figures both live in the database, which the
  // gate in front of the app loads — or offers to populate — on first frame.
  runApp(const PickStockApp());
}
