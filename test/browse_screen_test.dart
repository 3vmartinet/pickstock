import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/sec/mock_sec_repo.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';
import 'package:pickstock/repo/sec/ticker_directory_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

const Size _desktopSize = Size(1440, 1200);

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final directory = TickerDirectoryRepo();
    await directory.load();
    GetIt.I
      ..registerLazySingleton<ThemeRepo>(ThemeRepo.new)
      ..registerLazySingleton<FormatRepo>(FormatRepo.new)
      ..registerSingleton<TickerDirectoryRepo>(directory)
      ..registerLazySingleton<SecRepo>(() => const MockSecRepo());
  });

  tearDown(GetIt.I.reset);

  testWidgets('lists the whole directory and narrows it on a query', (
    tester,
  ) async {
    await _openBrowser(tester);

    expect(find.text('All tickers'), findsOneWidget);
    // Counts are grouped, not bare digits.
    expect(find.text('10,391 symbols filed with SEC EDGAR'), findsOneWidget);
    expect(find.text('10,391 matches'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'BRK-');
    await tester.pumpAndSettle();

    expect(find.text('2 matches'), findsOneWidget);
    expect(find.text('BRK-A'), findsOneWidget);
    expect(find.text('BRK-B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('matches company names as well as symbols', (tester) async {
    await _openBrowser(tester);

    await tester.enterText(find.byType(TextField).last, 'berkshire');
    await tester.pumpAndSettle();

    expect(find.text('BRK-A'), findsOneWidget);
    expect(find.text('BRK-B'), findsOneWidget);
  });

  testWidgets('explains an empty result rather than showing a blank grid', (
    tester,
  ) async {
    await _openBrowser(tester);

    await tester.enterText(find.byType(TextField).last, 'zzzzzzz');
    await tester.pumpAndSettle();

    expect(find.text('No matches'), findsOneWidget);
    expect(find.text('No matching symbols'), findsOneWidget);
  });

  testWidgets('picking a symbol returns to the report and looks it up', (
    tester,
  ) async {
    await _openBrowser(tester);

    await tester.enterText(find.byType(TextField).last, 'AAPL');
    await tester.pumpAndSettle();
    // By name, not symbol: the symbol also appears in the filter field.
    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();

    // Back on the report, with the picked symbol fetched.
    expect(find.text('All tickers'), findsNothing);
    expect(find.text('Apple Inc.'), findsOneWidget);
    expect(find.text('FY2025 highlights'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openBrowser(WidgetTester tester) async {
  tester.view
    ..physicalSize = _desktopSize
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const PickStockApp());
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(LucideIcons.list));
  await tester.pumpAndSettle();
}
