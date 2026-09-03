import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/snapshot/snapshot_metric.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A year holding [cash] against [debt], which is all the balance-sheet card
/// reads.
FiscalYearFigures _year(double debt, double cash) =>
    FiscalYearFigures(fiscalYear: 2025, totalDebt: debt, cash: cash);

const double _billion = 1000000000;
const double _million = 1000000;

void main() {
  late AppLocalizations strings;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GetIt.I.registerLazySingleton<FormatRepo>(FormatRepo.new);
    strings = await AppLocalizations.delegate.load(const Locale('en'));
  });

  tearDownAll(GetIt.I.reset);

  ({String text, bool? isGood})? position(
    FiscalYearFigures now,
    FiscalYearFigures? before,
  ) => SnapshotMetric.netCashPosition.getPriorPosition(strings, now, before);

  test('net cash that shrank reads as a fall, and as bad news', () {
    // Adobe FY2025: $385M of net cash where FY2024 had $2.26B. The card used
    // to say only "was net cash of $2.26B", in a muted grey, under a green
    // $385M — which read as though the position had improved to $385M.
    final result = position(
      _year(5 * _billion, 5.385 * _billion),
      _year(5 * _billion, 7.26 * _billion),
    )!;

    expect(result.text, 'down from net cash of \$2.26B');
    expect(result.isGood, isFalse);
  });

  test('net cash that grew reads as a rise, and as good news', () {
    final result = position(
      _year(5 * _billion, 8 * _billion),
      _year(5 * _billion, 7.26 * _billion),
    )!;

    expect(result.text, 'up from net cash of \$2.26B');
    expect(result.isGood, isTrue);
  });

  test('net debt that grew is bad news even though the amount rose', () {
    final result = position(
      _year(44 * _billion, 0),
      _year(41.5 * _billion, 0),
    )!;

    expect(result.text, 'up from net debt of \$41.5B');
    expect(result.isGood, isFalse);
  });

  test('net debt that shrank is good news', () {
    final result = position(
      _year(41.5 * _billion, 0),
      _year(44 * _billion, 0),
    )!;

    expect(result.text, 'down from net debt of \$44B');
    expect(result.isGood, isTrue);
  });

  group('crossing zero renames the card, so the words stay plain', () {
    test('debt turned into cash', () {
      // No direction: "down from net debt" under a heading of Net cash would
      // compare two different quantities.
      final result = position(
        _year(1 * _billion, 1.385 * _billion),
        _year(1 * _billion, 0),
      )!;

      expect(result.text, 'was net debt of \$1B');
      expect(result.isGood, isTrue);
    });

    test('cash turned into debt', () {
      final result = position(
        _year(3 * _billion, 2 * _billion),
        _year(1 * _billion, 3 * _billion),
      )!;

      expect(result.text, 'was net cash of \$2B');
      expect(result.isGood, isFalse);
    });
  });

  test('a position that did not move is neither good nor bad news', () {
    final result = position(
      _year(1 * _billion, 500 * _million),
      _year(1 * _billion, 500 * _million),
    )!;

    expect(result.text, 'was net debt of \$500M');
    expect(result.isGood, isNull);
  });

  test('says nothing without both years on file', () {
    expect(position(_year(1 * _billion, 0), null), isNull);
    // Debt unreported, so there is no position to compare.
    expect(
      position(
        const FiscalYearFigures(fiscalYear: 2025, cash: 1),
        _year(1 * _billion, 0),
      ),
      isNull,
    );
  });

  test('the other three cards compare as percentages, not in words', () {
    for (final metric in SnapshotMetric.values) {
      if (metric == SnapshotMetric.netCashPosition) continue;
      expect(
        metric.getPriorPosition(
          strings,
          _year(1 * _billion, 0),
          _year(2 * _billion, 0),
        ),
        isNull,
        reason: '${metric.name} should not state a position',
      );
    }
  });
}
