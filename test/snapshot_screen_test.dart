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

/// Wide enough that the old layout used the eight-column table, narrow enough
/// that it had to squeeze it — which wrapped figures mid-number.
const Size _mediumSize = Size(800, 1400);
const Size _phoneSize = Size(420, 900);

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The search field resolves what is typed against the bundled directory.
    final directory = TickerDirectoryRepo();
    await directory.load();
    GetIt.I
      ..registerLazySingleton<ThemeRepo>(ThemeRepo.new)
      ..registerLazySingleton<FormatRepo>(FormatRepo.new)
      ..registerSingleton<TickerDirectoryRepo>(directory)
      ..registerLazySingleton<SecRepo>(() => const MockSecRepo());
  });

  tearDown(GetIt.I.reset);

  testWidgets('renders the full report for a known ticker', (tester) async {
    await _pumpApp(tester, _desktopSize);

    expect(find.text('Check a company before you invest'), findsOneWidget);

    await _search(tester, 'AAPL');

    expect(find.text('Apple Inc.'), findsOneWidget);
    expect(find.text('CIK 0000320193'), findsOneWidget);
    // Sanity checks, answered from the fixture's FY2025 figures.
    expect(find.text('Growing +6.4% year over year'), findsOneWidget);
    expect(find.text('Net income of \$112B'), findsOneWidget);
    expect(find.text('Net debt of \$62.7B'), findsOneWidget);
    // The history table, in millions as the console report had it.
    expect(find.text('416,161'), findsOneWidget);
    // Fiscal years read as years, not as compacted numbers.
    expect(find.text('FY2023 – FY2025'), findsOneWidget);
    expect(find.text('FY2025 highlights'), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('383,285'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to per-year cards on a narrow window', (
    tester,
  ) async {
    await _pumpApp(tester, _phoneSize);
    await _search(tester, 'AAPL');

    // The wide table is gone, but every year is still on screen.
    expect(find.byType(Table), findsNothing);
    expect(find.text('FY2025'), findsOneWidget);
    expect(find.text('FY2024'), findsOneWidget);
    expect(find.text('FY2023'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drops the table before its columns can squeeze', (tester) async {
    await _pumpApp(tester, _mediumSize);
    await _search(tester, 'AAPL');

    // At this width the table cannot fit eight columns without wrapping
    // figures across two lines, so the per-year cards stand in for it.
    expect(find.byType(Table), findsNothing);
    for (final year in ['FY2023', 'FY2024', 'FY2025']) {
      expect(find.text(year), findsOneWidget);
    }
    expect(find.text('215,938'), findsNothing, reason: 'AAPL, not NVDA');
    expect(tester.takeException(), isNull);
  });

  testWidgets('suggests matches for a symbol as it is typed', (tester) async {
    await _pumpApp(tester, _desktopSize);

    // The field used to cap at five characters and strip '-', which turned
    // BRK-B into BRKB and made 543 symbols unreachable.
    await tester.enterText(find.byType(TextField), 'brk-b');
    await _pumpSuggestions(tester);

    expect(find.textContaining('BRK-B'), findsWidgets);
    expect(find.textContaining('BERKSHIRE HATHAWAY INC'), findsOneWidget);
  });

  testWidgets('suggests matches for a company name too', (tester) async {
    await _pumpApp(tester, _desktopSize);

    await tester.enterText(find.byType(TextField), 'apple inc');
    await _pumpSuggestions(tester);

    expect(find.textContaining('AAPL'), findsWidgets);
  });

  testWidgets('picking a suggestion runs that lookup', (tester) async {
    await _pumpApp(tester, _desktopSize);

    await tester.enterText(find.byType(TextField), 'apple inc');
    await _pumpSuggestions(tester);
    await tester.tap(find.text('AAPL  ·  Apple Inc.'));
    await _pumpSuggestions(tester);

    expect(find.text('FY2025 highlights'), findsOneWidget);
    // The field is left holding the symbol, not the name that was typed.
    expect(find.text('AAPL'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pressing enter on a company name resolves it to a symbol', (
    tester,
  ) async {
    await _pumpApp(tester, _desktopSize);

    // A typed name used to be sent to EDGAR verbatim and fail.
    await tester.enterText(find.byType(TextField), 'apple inc');
    await _pumpSuggestions(tester);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _pumpSuggestions(tester);

    expect(find.text('FY2025 highlights'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('orders the history newest first by default, and flips', (
    tester,
  ) async {
    await _pumpApp(tester, _desktopSize);
    await _search(tester, 'AAPL');

    double yOf(String year) => tester.getTopLeft(find.text(year)).dy;

    // Newest first is the default: the year being judged leads.
    expect(yOf('FY2025'), lessThan(yOf('FY2023')));

    await tester.tap(find.text('Newest first'));
    await tester.pumpAndSettle();

    expect(find.text('Oldest first'), findsOneWidget);
    expect(yOf('FY2025'), greaterThan(yOf('FY2023')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the compact card list follows the same order', (tester) async {
    await _pumpApp(tester, _mediumSize);
    await _search(tester, 'AAPL');

    double yOf(String year) => tester.getTopLeft(find.text(year)).dy;
    expect(find.byType(Table), findsNothing);
    expect(yOf('FY2025'), lessThan(yOf('FY2023')));

    await tester.tap(find.text('Newest first'));
    await tester.pumpAndSettle();

    expect(yOf('FY2025'), greaterThan(yOf('FY2023')));
  });

  testWidgets('explains an unknown ticker instead of failing silently', (
    tester,
  ) async {
    await _pumpApp(tester, _desktopSize);
    await _search(tester, 'ZZZZ');

    expect(find.text('Could not build a snapshot'), findsOneWidget);
    expect(
      find.text('No SEC filer matches the ticker "ZZZZ".'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const PickStockApp());
  await tester.pumpAndSettle();
}

/// The suggestion popover keeps scheduling frames while it is open, so
/// `pumpAndSettle` never returns; pump a fixed span instead.
Future<void> _pumpSuggestions(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _search(WidgetTester tester, String ticker) async {
  await tester.enterText(find.byType(TextField), ticker);
  await tester.tap(find.text('Analyze'));
  await tester.pumpAndSettle();
}
