import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/sec/bulk_ingest_repo.dart';

/// A filer whose figures identify it, so a company that ended up with another
/// one's numbers is caught rather than merely counted.
///
/// [years] varies the payload size by a factor of twenty across the archive,
/// which is what makes workers finish out of turn — the case a single worker
/// never exercised.
Map<String, dynamic> _facts(int cik, {required int years}) {
  Map<String, dynamic> annual(String tag, int year, num value) => {
    'units': {
      'USD': [
        for (var back = 0; back < years; back++)
          {
            'accn': 'a-${year - back}',
            'fy': year - back,
            'fp': 'FY',
            'form': '10-K',
            'start': '${year - back - 1}-10-01',
            'end': '${year - back}-09-30',
            'val': value - back,
          },
      ],
    },
  };

  return {
    'entityName': 'Filer $cik',
    'facts': {
      'us-gaap': {
        // The revenue is the filer's own CIK, so every row can be traced back
        // to the entry it should have come from.
        'RevenueFromContractWithCustomerExcludingAssessedTax': annual(
          'revenue',
          2025,
          cik * 1000,
        ),
        'NetCashProvidedByUsedInOperatingActivities': annual(
          'cash',
          2025,
          cik * 100,
        ),
      },
    },
  };
}

String _padded(int cik) => cik.toString().padLeft(10, '0');

/// An archive shaped like SEC's, with non-filer entries scattered through it.
///
/// Their placement is the point: entries are sliced by their index in the
/// archive, so a README between two filers must not shift the ones after it.
List<int> _archiveBytes(List<int> ciks) {
  final archive = Archive();
  for (var position = 0; position < ciks.length; position++) {
    if (position % 37 == 0) {
      archive.add(
        ArchiveFile.bytes(
          'notes/README-$position.txt',
          utf8.encode('not a filer'),
        ),
      );
    }
    final cik = ciks[position];
    archive.add(
      ArchiveFile.bytes(
        'CIK${_padded(cik)}.json',
        utf8.encode(jsonEncode(_facts(cik, years: 1 + position % 20))),
      ),
    );
  }
  return ZipEncoder().encode(archive);
}

void main() {
  late AppDatabase database;
  late Directory workingDirectory;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workingDirectory = await Directory.systemTemp.createTemp('pickstock-test');
    GetIt.I.registerSingleton<AppDatabase>(database);
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
    if (workingDirectory.existsSync()) {
      await workingDirectory.delete(recursive: true);
    }
  });

  BulkIngestRepo repoServing(List<int> archiveBytes, {int? workers}) =>
      BulkIngestRepo(
        workingDirectory: workingDirectory,
        parseWorkers: workers,
        client: MockClient((request) async {
          if (request.url.path.contains('financial-statement-data-sets')) {
            return http.Response('', 404);
          }
          if (request.url.toString() == tickerDirectoryUrl) {
            return http.Response(jsonEncode(const <String, dynamic>{}), 200);
          }
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

  Future<List<CompanyRow>> storedCompanies() =>
      database.select(database.companies).get();

  group('how wide to parse', () {
    test('leaves the machine as much as it takes', () {
      // Half the cores: the other half runs the isolate writing to the
      // database, draws the app, and is what the readers would be contending
      // with for memory if they were given it.
      expect(parseWorkerCount(processors: 4), 2);
      expect(parseWorkerCount(processors: 6), 3);
    });

    test('still parses in the background on a machine with nothing spare', () {
      // One background worker beats none even here: with the archive open on
      // the far side of a port it reads the next slice while this one is
      // written, which the old one-at-a-time loop could not do.
      expect(parseWorkerCount(processors: 1), 1);
      expect(parseWorkerCount(processors: 2), 1);
    });

    test('stops growing where measurement says it stops paying', () {
      // A twelve-core machine loaded in 8.0s at four workers and 15.2s at
      // eight, so a bigger machine is not given a wider load.
      expect(parseWorkerCount(processors: 8), 4);
      expect(parseWorkerCount(processors: 12), 4);
      expect(parseWorkerCount(processors: 128), 4);
    });

    test('asks the machine when it is not told', () {
      expect(parseWorkerCount(), inInclusiveRange(1, 4));
    });
  });

  group('a load spread across workers', () {
    // 500 filers over slices of 64: eight slices, so six workers have to be
    // handed a second one — which is where a dropped or repeated slice shows.
    final ciks = [for (var index = 0; index < 500; index++) 100000 + index * 7];

    test('stores every filer exactly once, whatever the width', () async {
      for (final workers in const [1, 3, 6]) {
        await database.clearFinancials();
        final progress = await repoServing(
          _archiveBytes(ciks),
          workers: workers,
        ).ingest().toList();

        final done = progress.last as IngestDone;
        // Not `greaterThan`: a slice handed out twice would still store every
        // filer, and this is the assertion that catches it.
        expect(done.companyCount, ciks.length, reason: '$workers workers');
        expect(await storedCompanies(), hasLength(ciks.length));
      }
    });

    test('gives every filer its own figures, not a neighbour\'s', () async {
      await repoServing(_archiveBytes(ciks), workers: 6).ingest().drain<void>();

      for (final cik in ciks) {
        final years = await database.yearsFor(_padded(cik));
        expect(years, isNotEmpty, reason: 'CIK $cik was not stored');
        // Seeded as the filer's own CIK, so a row that travelled between
        // workers or slices lands on the wrong company here.
        expect(
          years.firstWhere((year) => year.fiscalYear == 2025).revenue,
          cik * 1000,
          reason: 'CIK $cik got the wrong figures',
        );
      }
    });

    test('keeps every year of every filer', () async {
      await repoServing(_archiveBytes(ciks), workers: 6).ingest().drain<void>();

      // Filers were given between 1 and 20 years, cycling with their position.
      final expected = <int>[
        for (var position = 0; position < ciks.length; position++)
          1 + position % 20,
      ];
      for (var position = 0; position < ciks.length; position++) {
        expect(
          await database.yearsFor(_padded(ciks[position])),
          hasLength(expected[position]),
          reason: 'CIK ${ciks[position]} lost a year',
        );
      }
    });

    test('a load at six workers matches a load at one, row for row', () async {
      Future<Map<String, double?>> load(int workers) async {
        await database.clearFinancials();
        await repoServing(
          _archiveBytes(ciks),
          workers: workers,
        ).ingest().drain<void>();
        return {
          for (final company in await storedCompanies())
            company.cik: (await database.yearsFor(company.cik))
                .firstWhere((year) => year.fiscalYear == 2025)
                .revenue,
        };
      }

      expect(await load(6), await load(1));
    });

    test('counts entries, not companies, so the bar reaches the end', () async {
      final progress = await repoServing(
        _archiveBytes(ciks),
        workers: 6,
      ).ingest().toList();

      final loading = progress.whereType<IngestLoading>().toList();
      // The READMEs are excluded from the total rather than counted and
      // skipped, and slices arriving out of order still sum to all of it.
      expect(loading.first.totalCompanies, ciks.length);
      expect(loading.last.companiesLoaded, ciks.length);
      expect(loading.last.fraction, 1.0);
      // And it only ever moves forward.
      for (var step = 1; step < loading.length; step++) {
        expect(
          loading[step].companiesLoaded,
          greaterThanOrEqualTo(loading[step - 1].companiesLoaded),
        );
      }
    });

    test('a broken filer costs only itself, at any width', () async {
      final archive = Archive();
      for (var position = 0; position < ciks.length; position++) {
        final broken = position == 200;
        archive.add(
          ArchiveFile.bytes(
            'CIK${_padded(ciks[position])}.json',
            utf8.encode(
              broken
                  ? '{ not json'
                  : jsonEncode(_facts(ciks[position], years: 3)),
            ),
          ),
        );
      }

      final progress = await repoServing(
        ZipEncoder().encode(archive),
        workers: 6,
      ).ingest().toList();

      expect((progress.last as IngestDone).companyCount, ciks.length - 1);
      // Including the filers either side of it, in the same slice.
      expect(await database.companyFor(_padded(ciks[199])), isNotNull);
      expect(await database.companyFor(_padded(ciks[200])), isNull);
      expect(await database.companyFor(_padded(ciks[201])), isNotNull);
      // And the bar still counts it as read.
      expect(
        progress.whereType<IngestLoading>().last.companiesLoaded,
        ciks.length,
      );
    });

    test('lets go of the archive, so the download can be cleared up', () async {
      // Six isolates hold the archive open while it is read; a load that did
      // not stop them would leave 1.4 GB on the user's disk.
      await repoServing(_archiveBytes(ciks), workers: 6).ingest().drain<void>();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(workingDirectory.listSync(), isEmpty);
    });
  });

  group('reading a slice', () {
    test('is the same work whether the archive is opened for it or not', () {
      final bytes = _archiveBytes([320193, 1045810, 789019]);
      final path = '${workingDirectory.path}/facts.zip';
      File(path).writeAsBytesSync(bytes);

      final input = InputFileStream(path);
      final archive = ZipDecoder().decodeStream(input);
      final filers = [
        for (var index = 0; index < archive.length; index++)
          if (archive[index].name.startsWith('CIK')) index,
      ];

      // The pooled workers hoist the opening out of the loop and nothing else.
      final pooled = parseArchiveEntries(archive, filers);
      input.closeSync();
      final standalone = parseArchiveSlice(path, filers);

      // Archive order, which is the order the entry indices were given in.
      expect(pooled.map((company) => company.cik), [
        '0000320193',
        '0001045810',
        '0000789019',
      ]);
      expect(
        standalone.map((company) => company.cik),
        pooled.map((company) => company.cik),
      );
      expect(
        standalone.map((company) => company.years.first.revenue),
        pooled.map((company) => company.years.first.revenue),
      );
    });
  });
}
