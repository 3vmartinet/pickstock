import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:pickstock/data/snapshot/browse_sort.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/data/snapshot/growth_metric.dart';
import 'package:pickstock/repo/db/app_database.dart';

const double _million = 1000000;

void main() {
  late AppDatabase database;

  /// Files [revenues] as consecutive fiscal years ending in 2025, skipping any
  /// year given as null so a gap in the filings can be modelled.
  Future<void> file(String cik, List<double?> revenues) async {
    final firstYear = 2025 - revenues.length + 1;
    // Foreign keys are on, so the filer has to exist before its years do.
    await database
        .into(database.companies)
        .insert(CompaniesCompanion.insert(cik: cik, name: cik));
    await database.batch((batch) {
      for (var index = 0; index < revenues.length; index++) {
        final revenue = revenues[index];
        if (revenue == null) continue;
        batch.insert(
          database.fiscalYears,
          FiscalYearsCompanion.insert(
            cik: cik,
            fiscalYear: firstYear + index,
            revenue: Value(revenue * _million),
          ),
        );
      }
    });
  }

  Future<Set<String>> ranked(int years) async {
    final samples = await database.growthSamples(
      metric: GrowthMetric.revenue,
      years: years,
      unbrokenOnly: true,
    );
    return {
      for (final entry in samples.entries)
        if (entry.value.annualisedPercent != null) entry.key,
    };
  }

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    // Up every single year.
    await file('steady', [100, 120, 140, 160, 180, 200]);
    // Up every year except one dip four years back.
    await file('dipped', [100, 120, 110, 160, 180, 200]);
    // Up every year, but 2021 is missing from the filings.
    await file('gappy', [100, null, 140, 160, 180, 200]);
    // Flat: not a rise.
    await file('flat', [100, 120, 140, 160, 180, 180]);
    // Only two years on file at all.
    await file('young', [180, 200]);
  });

  tearDown(() async => database.close());

  test('ranks only companies that rose in every year of the window', () async {
    expect(await ranked(2), {'steady', 'dipped', 'gappy'});
  });

  test('a dip inside the window breaks the run', () async {
    // The dip is the 2021→2022 step, inside a five-year window and outside a
    // three-year one.
    expect(await ranked(3), contains('dipped'));
    expect(await ranked(5), isNot(contains('dipped')));
    expect(await ranked(5), contains('steady'));
  });

  test(
    'a missing year breaks the run rather than being read through',
    () async {
      // The recent years are unbroken, so the short windows rank it.
      expect(await ranked(2), contains('gappy'));
      expect(await ranked(3), contains('gappy'));
      // 2021 is absent, so there is no 2021→2022 step to call a rise and the
      // longer windows cannot claim an unbroken one.
      expect(await ranked(4), isNot(contains('gappy')));
      expect(await ranked(5), isNot(contains('gappy')));
    },
  );

  test('flat is not a rise', () async {
    expect(await ranked(2), isNot(contains('flat')));
    expect(await ranked(5), isNot(contains('flat')));
  });

  test('too little history is unrankable, not a failure', () async {
    expect(await ranked(2), isNot(contains('young')));
    expect(await ranked(5), isNot(contains('young')));
  });

  test('without the flag every company with two ends is ranked', () async {
    final samples = await database.growthSamples(
      metric: GrowthMetric.revenue,
      years: 5,
    );
    final rankable = {
      for (final entry in samples.entries)
        if (entry.value.annualisedPercent != null) entry.key,
    };
    // The dip and the flat year are irrelevant to a plain five-year rate.
    expect(rankable, containsAll(['steady', 'dipped', 'flat']));
  });

  test(
    'there is a run-of-growth option per window, plainly labelled',
    () async {
      final strings = await AppLocalizations.delegate.load(const Locale('en'));
      const options = {
        BrowseSort.revenueRisingTwoYears: 2,
        BrowseSort.revenueRisingThreeYears: 3,
        BrowseSort.revenueRisingFiveYears: 5,
        BrowseSort.revenueRisingTenYears: 10,
      };

      for (final option in options.entries) {
        expect(option.key.years, option.value);
        expect(option.key.needsUnbrokenRun, isTrue);
        expect(
          option.key.getLabel(strings),
          'Revenue up ${option.value} years running',
        );
      }
    },
  );

  test('the new options ask for an unbroken run, the old ones do not', () {
    expect(BrowseSort.revenueRisingFiveYears.needsUnbrokenRun, isTrue);
    expect(BrowseSort.revenueRisingFiveYears.years, 5);
    expect(BrowseSort.revenueFiveYears.needsUnbrokenRun, isFalse);
    expect(BrowseSort.name.needsUnbrokenRun, isFalse);
  });
}
