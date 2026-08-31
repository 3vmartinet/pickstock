import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/data/snapshot/sic_sector.dart';

/// Real codes taken from the filers in the directory, one per block that the
/// mapping had to be extended to cover.
const Map<int, SicSector> _knownCodes = {
  100: SicSector.materials, // agricultural production, crops
  700: SicSector.materials, // agricultural services
  1311: SicSector.energy, // crude petroleum and natural gas
  2834: SicSector.healthcare, // pharmaceutical preparations
  3571: SicSector.technology, // electronic computers
  3674: SicSector.technology, // semiconductors
  3711: SicSector.automotive, // motor vehicles
  3812: SicSector.industrials, // search, detection and navigation
  3823: SicSector.industrials, // industrial process instruments
  3826: SicSector.healthcare, // laboratory analytical instruments
  3861: SicSector.consumer, // photographic equipment
  3873: SicSector.consumer, // watches and clocks
  4813: SicSector.communications, // telephone communications
  4911: SicSector.utilities, // electric services
  6021: SicSector.financials, // national commercial banks
  6798: SicSector.realEstate, // real estate investment trusts
  7200: SicSector.consumer, // personal services
  7372: SicSector.technology, // prepackaged software
  7500: SicSector.automotive, // auto services
  7812: SicSector.communications, // motion picture production
  7900: SicSector.consumer, // amusement and recreation
  8111: SicSector.industrials, // legal services
  8200: SicSector.consumer, // educational services
  8351: SicSector.consumer, // child day care
  8731: SicSector.industrials, // commercial physical research
  8900: SicSector.industrials, // services, not elsewhere classified
};

void main() {
  test('places every code the directory actually carries', () {
    for (final entry in _knownCodes.entries) {
      expect(
        SicSector.of(entry.key),
        entry.value,
        reason: 'SIC ${entry.key} landed in the wrong sector',
      );
    }
  });

  test('no two sectors claim the same code', () {
    // Ranges are searched in declaration order and the first match wins, so an
    // overlap silently hands a whole block to whichever sector is declared
    // first — a mistake that is invisible until someone filters by the other.
    final owner = <int, SicSector>{};
    for (final sector in SicSector.values) {
      for (final (from, to) in sector.ranges) {
        expect(
          from,
          lessThanOrEqualTo(to),
          reason: '$sector has a backwards range',
        );
        for (var code = from; code <= to; code++) {
          final existing = owner[code];
          expect(
            existing,
            isNull,
            reason: 'SIC $code is claimed by both $existing and $sector',
          );
          owner[code] = sector;
        }
      }
    }
  });

  test('leaves codes outside the SIC space unclassified', () {
    expect(SicSector.of(null), isNull);
    expect(SicSector.of(0), isNull);
    expect(SicSector.of(9999), isNull);
  });
}
