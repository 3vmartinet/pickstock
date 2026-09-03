import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/data/snapshot/sic_industry.dart';
import 'package:pickstock/data/snapshot/sic_sector.dart';

void main() {
  test('states what a company does in SEC\'s own words', () {
    // Verified against what EDGAR's submissions endpoint returns as
    // `sicDescription` for the filers on these codes, character for
    // character — the table is that field, read locally.
    expect(SicIndustry.of(3571), 'Electronic Computers');
    expect(SicIndustry.of(7372), 'Services-Prepackaged Software');
    expect(SicIndustry.of(5961), 'Retail-Catalog & Mail-Order Houses');
    expect(SicIndustry.of(6331), 'Fire, Marine & Casualty Insurance');
    expect(SicIndustry.of(4813), 'Telephone Communications (No Radiotelephone)');
    expect(
      SicIndustry.of(7370),
      'Services-Computer Programming, Data Processing, Etc.',
    );
  });

  test('says nothing about a filer whose code was never collected', () {
    expect(SicIndustry.of(null), isNull);
    // Not a code SEC lists.
    expect(SicIndustry.of(9998), isNull);
  });

  test('carries the whole of SEC\'s published list, readably', () {
    final listed = <int, String>{
      for (var sic = 0; sic < 10000; sic++) sic: ?SicIndustry.of(sic),
    };

    // SEC's SIC code list runs to 444 codes. A table that lost half of them
    // in generation would still pass every case above.
    expect(listed, hasLength(444));
    for (final entry in listed.entries) {
      expect(entry.value.trim(), entry.value, reason: 'SIC ${entry.key}');
      expect(entry.value, isNotEmpty, reason: 'SIC ${entry.key}');
      // Title-cased like EDGAR's own field rather than the SHOUTED form the
      // published list uses.
      expect(
        entry.value,
        isNot(equals(entry.value.toUpperCase())),
        reason: 'SIC ${entry.key} reads as ${entry.value}',
      );
    }
  });

  test('every sector chip has industries behind it', () {
    // The sector filter and the industry title are read from the same code,
    // so a sector whose ranges catch nothing SEC lists would be a chip that
    // filters the directory down to nothing.
    for (final sector in SicSector.values) {
      final codes = [
        for (var sic = 0; sic < 10000; sic++)
          if (SicSector.of(sic) == sector && SicIndustry.of(sic) != null) sic,
      ];
      expect(codes, isNotEmpty, reason: 'no listed SIC code is ${sector.name}');
    }
  });
}
