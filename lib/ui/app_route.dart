import 'package:pickstock/ui/company/company_screen.dart';
import 'package:pickstock/ui/home/home_screen.dart';
import 'package:pickstock/ui/ingest/ingest_gate.dart';
import 'package:pickstock/ui/report/report_screen.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Every destination in the app, and how to build it.
enum AppRoute {
  /// The ticker list, which is the app's main screen.
  home(path: '/'),

  /// One company's report. Only pushed on windows too narrow to show it
  /// beside the list.
  company(path: '/company'),

  /// One finished scan, opened from the jobs panel. Takes the report's id as
  /// its route argument.
  report(path: '/report');

  const AppRoute({required this.path});

  final String path;

  /// Every destination sits behind the ingest gate: none of them has anything
  /// to show until the local database is populated.
  Widget build() => IngestGate(child: _screen());

  Widget _screen() => switch (this) {
    AppRoute.home => const HomeScreen(),
    AppRoute.company => const CompanyScreen(),
    AppRoute.report => const ReportScreen(),
  };

  static Map<String, WidgetBuilder> get routes => {
    for (final route in values) route.path: (_) => route.build(),
  };
}
