import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

/// Wide enough that the report pane beside the list still clears the history
/// table's minimum: the list takes 420px of it.
const Size _desktopSize = Size(1600, 1200);

/// Wide enough that the old layout used the eight-column table, narrow enough
/// that it had to squeeze it — which wrapped figures mid-number.
const Size _mediumSize = Size(800, 1400);
const Size _phoneSize = Size(420, 900);

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await registerTestDependencies();
  });

  tearDown(GetIt.I.reset);

  testWidgets('renders the full report for a known ticker', (tester) async {
    await _pumpApp(tester, _desktopSize);

    expect(find.text('Check a company before you invest'), findsOneWidget);

    await _search(tester, 'AAPL');

    // Once in the list, once in the report beside it.
    expect(find.text('Apple Inc.'), findsWidgets);
    expect(find.text('CIK 0000320193'), findsOneWidget);
    // Fiscal years read as years, not as compacted numbers. The header used to
    // carry the span as a badge; the table below names the years it shows.
    expect(find.text('FY2025'), findsWidgets);
    // Sanity checks, answered from the fixture's FY2025 figures.
    expect(find.text('Growing +6.4% year over year'), findsOneWidget);
    expect(find.text('Net income of \$112B'), findsOneWidget);
    expect(find.text('Net debt of \$44B'), findsOneWidget);
    expect(find.text('FY2025 highlights'), findsOneWidget);
    // The history table sits with them, in millions as the console report had
    // it.
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('416,161'), findsOneWidget);
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

  testWidgets('narrows the list to a symbol as it is typed', (tester) async {
    await _pumpApp(tester, _desktopSize);

    // The field used to cap at five characters and strip '-', which turned
    // BRK-B into BRKB and made 543 symbols unreachable.
    await tester.enterText(find.byType(TextField), 'brk-b');
    await _pumpSuggestions(tester);

    expect(find.textContaining('BRK-B'), findsWidgets);
    expect(find.textContaining('BERKSHIRE HATHAWAY INC'), findsOneWidget);
  });

  testWidgets('narrows the list by company name too', (tester) async {
    await _pumpApp(tester, _desktopSize);

    await tester.enterText(find.byType(TextField), 'apple inc');
    await _pumpSuggestions(tester);

    expect(find.textContaining('AAPL'), findsWidgets);
  });

  testWidgets('enter opens whatever is at the top of the list', (tester) async {
    await _pumpApp(tester, _desktopSize);

    await tester.enterText(find.byType(TextField), 'apple inc');
    await _pumpSuggestions(tester);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _pumpSuggestions(tester);

    expect(find.text('FY2025 highlights'), findsOneWidget);
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

  testWidgets('switches the history between annual and quarterly', (
    tester,
  ) async {
    await _pumpApp(tester, _desktopSize);
    await _search(tester, 'AAPL');

    // Opens on annual, matching the highlights above it.
    expect(find.text('FY2025'), findsWidgets);
    expect(find.text('Q1 FY2025'), findsNothing);

    await tester.tap(find.text('Quarterly'));
    await tester.pumpAndSettle();

    expect(find.text('Q1 FY2025'), findsOneWidget);
    expect(find.text('Q4 FY2025'), findsOneWidget);
    expect(find.text('Last 4 quarters'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Annual'));
    await tester.pumpAndSettle();
    expect(find.text('Q1 FY2025'), findsNothing);
  });

  testWidgets('the quarterly view sorts and reverses like the annual one', (
    tester,
  ) async {
    await _pumpApp(tester, _desktopSize);
    await _search(tester, 'AAPL');
    await tester.tap(find.text('Quarterly'));
    await tester.pumpAndSettle();

    double yOf(String label) => tester.getTopLeft(find.text(label)).dy;
    expect(yOf('Q4 FY2025'), lessThan(yOf('Q1 FY2025')));

    await tester.tap(find.text('Newest first'));
    await tester.pumpAndSettle();
    expect(yOf('Q4 FY2025'), greaterThan(yOf('Q1 FY2025')));
  });

  testWidgets('says so when nothing matches, leaving the report alone', (
    tester,
  ) async {
    await _pumpApp(tester, _desktopSize);

    await tester.enterText(find.byType(TextField), 'ZZZZ');
    await _pumpSuggestions(tester);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _pumpSuggestions(tester);

    // No company to open, so the list reports the miss and the detail pane
    // keeps its empty state rather than showing a lookup failure.
    expect(find.text('No matching symbols'), findsOneWidget);
    expect(find.text('Check a company before you invest'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

/// The list filters as you type; pump a fixed span rather than settling, since
/// the report's entrance animations repeat.
Future<void> _pumpSuggestions(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _search(WidgetTester tester, String ticker) async {
  // The filter above the list is the search field: typing narrows the list and
  // enter opens whatever is at the top of it.
  await tester.enterText(find.byType(TextField), ticker);
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}
