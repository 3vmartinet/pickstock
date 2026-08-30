import 'package:pickstock/ui/browse/browse_screen.dart';
import 'package:pickstock/ui/snapshot/snapshot_screen.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Every destination in the app, and how to build it.
enum AppRoute {
  snapshot(path: '/'),
  browse(path: '/browse');

  const AppRoute({required this.path});

  final String path;

  Widget build() => switch (this) {
    AppRoute.snapshot => const SnapshotScreen(),
    AppRoute.browse => const BrowseScreen(),
  };

  static Map<String, WidgetBuilder> get routes => {
    for (final route in values) route.path: (_) => route.build(),
  };
}
