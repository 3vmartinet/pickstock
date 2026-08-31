import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/data/snapshot/sic_sector.dart';

void main() {
  test('places well-known codes in the sector you would expect', () {
    // 3674 is NVIDIA's: semiconductors.
    expect(SicSector.of(3674), SicSector.technology);
    // 7372 prepackaged software, 2834 pharmaceutical preparations.
    expect(SicSector.of(7372), SicSector.technology);
    expect(SicSector.of(2834), SicSector.healthcare);
    // 3711 is motor vehicles, carved out of the surrounding industrials.
    expect(SicSector.of(3711), SicSector.automotive);
    expect(SicSector.of(3714), SicSector.industrials);
    expect(SicSector.of(6022), SicSector.financials);
    expect(SicSector.of(4911), SicSector.utilities);
    expect(SicSector.of(6798), SicSector.realEstate);
  });

  test('leaves a code outside every range unclassified', () {
    // Agriculture and public administration are too rare among filers to earn
    // a filter of their own.
    expect(SicSector.of(100), isNull);
    expect(SicSector.of(9995), isNull);
    expect(SicSector.of(null), isNull);
  });

  test('no two sectors claim the same code', () {
    for (var sic = 100; sic <= 9999; sic++) {
      final matches = SicSector.values
          .where(
            (sector) => sector.ranges.any((r) => sic >= r.$1 && sic <= r.$2),
          )
          .toList();
      expect(
        matches.length,
        lessThanOrEqualTo(1),
        reason: 'SIC $sic is claimed by ${matches.map((s) => s.name)}',
      );
    }
  });
}
