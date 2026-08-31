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

/// A filer payload in the shape the bulk archive holds.
Map<String, dynamic> _facts(String name, {required int fy, required num val}) =>
    {
      'entityName': name,
      'facts': {
        'us-gaap': {
          'RevenueFromContractWithCustomerExcludingAssessedTax': {
            'units': {
              'USD': [
                {
                  'accn': 'a-$fy',
                  'fy': fy,
                  'fp': 'FY',
                  'form': '10-K',
                  'start': '${fy - 1}-10-01',
                  'end': '$fy-09-30',
                  'val': val,
                },
              ],
            },
          },
          'NetCashProvidedByUsedInOperatingActivities': {
            'units': {
              'USD': [
                {
                  'accn': 'a-$fy',
                  'fy': fy,
                  'fp': 'FY',
                  'form': '10-K',
                  'start': '${fy - 1}-10-01',
                  'end': '$fy-09-30',
                  'val': val / 2,
                },
              ],
            },
          },
        },
      },
    };

/// A quarterly financial statement data set, shaped like SEC's: a tab-separated
/// `sub.txt` whose columns include `cik` and `sic`.
List<int> _sectorDataSetBytes(Map<int, int> sicByCik) {
  final rows = <String>[
    ['adsh', 'cik', 'name', 'sic', 'countryba'].join('\t'),
    for (final entry in sicByCik.entries)
      [
        '0000-00-000',
        '${entry.key}',
        'Filer',
        '${entry.value}',
        'US',
      ].join('\t'),
  ];
  final archive = Archive()
    ..add(ArchiveFile.bytes('sub.txt', utf8.encode(rows.join('\n'))));
  return ZipEncoder().encode(archive);
}

/// Builds a zip shaped like SEC's: one `CIK##########.json` per filer.
List<int> _archiveBytes(Map<String, Map<String, dynamic>> filesByName) {
  final archive = Archive();
  filesByName.forEach((name, facts) {
    final bytes = utf8.encode(jsonEncode(facts));
    archive.add(ArchiveFile.bytes(name, bytes));
  });
  return ZipEncoder().encode(archive);
}

/// The stream's error reaches the consumer before the generator's `finally`
/// has finished deleting the archive, so cleanup assertions wait a beat.
Future<void> _settleCleanup() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  late AppDatabase database;
  late Directory workingDirectory;
  var sectorsServed = 0;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workingDirectory = await Directory.systemTemp.createTemp('pickstock-test');
    sectorsServed = 0;
    GetIt.I.registerSingleton<AppDatabase>(database);
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
    if (workingDirectory.existsSync()) {
      await workingDirectory.delete(recursive: true);
    }
  });

  /// The ingest makes two requests: the small ticker directory, then the
  /// archive. The fake serves both, keyed by URL.
  BulkIngestRepo repoServing(
    List<int> archiveBytes, {
    Map<String, dynamic>? directory,
  }) => BulkIngestRepo(
    workingDirectory: workingDirectory,
    client: MockClient((request) async {
      // The sector data sets are optional; absent ones are skipped.
      if (request.url.path.contains('financial-statement-data-sets')) {
        return http.Response('', 404);
      }
      if (request.url.toString() == tickerDirectoryUrl) {
        return http.Response(
          jsonEncode(
            directory ??
                {
                  '0': {
                    'cik_str': 320193,
                    'ticker': 'AAPL',
                    'title': 'Apple Inc.',
                  },
                },
          ),
          200,
        );
      }
      return http.Response.bytes(archiveBytes, 200);
    }),
  );

  test('loads every filer in the archive into the database', () async {
    final bytes = _archiveBytes({
      'CIK0000320193.json': _facts('Apple Inc.', fy: 2025, val: 400),
      'CIK0001045810.json': _facts('NVIDIA CORP', fy: 2025, val: 200),
    });

    final progress = await repoServing(bytes).ingest().toList();

    expect(progress.last, isA<IngestDone>());
    expect((progress.last as IngestDone).companyCount, 2);
    expect(await database.companyFor('0000320193'), isNotNull);
    expect((await database.companyFor('0001045810'))!.name, 'NVIDIA CORP');
    expect(await database.yearsFor('0000320193'), hasLength(1));
  });

  test('records the ingest so reads know the database is populated', () async {
    await repoServing(
      _archiveBytes({
        'CIK0000320193.json': _facts('Apple Inc.', fy: 2025, val: 400),
      }),
    ).ingest().drain<void>();

    final run = await database.lastIngest();
    expect(run, isNotNull);
    expect(run!.companyCount, 1);
    expect(run.extractorVersion, extractorVersion);
  });

  test('skips entries that are not filer payloads', () async {
    final bytes = _archiveBytes({
      'CIK0000320193.json': _facts('Apple Inc.', fy: 2025, val: 400),
      'README.txt': {'not': 'a filer'},
    });

    final progress = await repoServing(bytes).ingest().toList();
    expect((progress.last as IngestDone).companyCount, 1);
  });

  test('skips a malformed filer rather than abandoning the archive', () async {
    final archive = Archive()
      ..add(ArchiveFile.bytes('CIK0000000001.json', utf8.encode('{ broken')))
      ..add(
        ArchiveFile.bytes(
          'CIK0000320193.json',
          utf8.encode(jsonEncode(_facts('Apple Inc.', fy: 2025, val: 400))),
        ),
      );

    final progress = await repoServing(ZipEncoder().encode(archive))
        .ingest()
        .toList();

    expect((progress.last as IngestDone).companyCount, 1);
    expect(await database.companyFor('0000320193'), isNotNull);
  });

  test('loads the ticker directory alongside the figures', () async {
    await repoServing(
      _archiveBytes({
        'CIK0000320193.json': _facts('Apple Inc.', fy: 2025, val: 400),
      }),
      directory: {
        '0': {'cik_str': 320193, 'ticker': 'AAPL', 'title': 'Apple Inc.'},
        '1': {'cik_str': 1067983, 'ticker': 'BRK-B', 'title': 'BERKSHIRE'},
      },
    ).ingest().drain<void>();

    final tickers = await database.allTickers();
    expect(tickers.map((t) => t.symbol), ['AAPL', 'BRK-B']);
    // Symbols arrive as CIKs padded to ten digits, matching the archive.
    expect(tickers.first.cik, '0000320193');
  });

  test('fetches the directory before the 1.4 GB archive', () async {
    final progress = await repoServing(
      _archiveBytes({
        'CIK0000320193.json': _facts('Apple Inc.', fy: 2025, val: 400),
      }),
    ).ingest().toList();

    expect(progress.first, isA<IngestFetchingDirectory>());
    expect(
      progress.indexWhere((p) => p is IngestDownloading),
      greaterThan(progress.indexWhere((p) => p is IngestFetchingDirectory)),
    );
  });

  test('records an industry code for each filer it can classify', () async {
    final archive = _archiveBytes({
      'CIK0000320193.json': _facts('Apple Inc.', fy: 2025, val: 400),
      'CIK0001045810.json': _facts('NVIDIA CORP', fy: 2025, val: 200),
    });
    // Apple is 3571, NVIDIA 3674; the third filer is not in the archive.
    final sectors = _sectorDataSetBytes({
      320193: 3571,
      1045810: 3674,
      99: 1234,
    });

    final repo = BulkIngestRepo(
      workingDirectory: workingDirectory,
      client: MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('financial-statement-data-sets')) {
          // Only the first probe hits, as in practice.
          return sectorsServed++ == 0
              ? http.Response.bytes(sectors, 200)
              : http.Response('', 404);
        }
        if (url == tickerDirectoryUrl) {
          return http.Response(
            jsonEncode({
              '0': {'cik_str': 320193, 'ticker': 'AAPL', 'title': 'Apple Inc.'},
            }),
            200,
          );
        }
        return http.Response.bytes(archive, 200);
      }),
    );

    final progress = await repo.ingest().toList();

    // The stage is reported, so the gate can show it.
    expect(progress.whereType<IngestFetchingSectors>(), isNotEmpty);
    // CIKs arrive unpadded in the data set and padded in the archive.
    expect((await database.companyFor('0000320193'))!.sic, 3571);
    expect((await database.companyFor('0001045810'))!.sic, 3674);
    expect(await database.sicByCik(), hasLength(2));
  });

  test('still ingests when no sector data set can be fetched', () async {
    // Sectors are a nice-to-have; the figures are not.
    final progress = await repoServing(
      _archiveBytes({
        'CIK0000320193.json': _facts('Apple Inc.', fy: 2025, val: 400),
      }),
    ).ingest().toList();

    expect(progress.last, isA<IngestDone>());
    expect((await database.companyFor('0000320193'))!.sic, isNull);
    expect(await database.sicByCik(), isEmpty);
  });

  test('reports loading progress as a fraction of the archive', () async {
    final progress = await repoServing(
      _archiveBytes({
        'CIK0000320193.json': _facts('Apple Inc.', fy: 2025, val: 400),
        'CIK0001045810.json': _facts('NVIDIA CORP', fy: 2025, val: 200),
        // Not a filer: excluded from the total, so the bar reaches 100%.
        'README.txt': {'not': 'a filer'},
      }),
    ).ingest().toList();

    final loading = progress.whereType<IngestLoading>().toList();
    expect(loading.first.totalCompanies, 2);
    expect(loading.first.companiesLoaded, 0);
    expect(loading.last.companiesLoaded, 2);
    expect(loading.last.fraction, 1.0);
  });

  test('reports download progress before parsing', () async {
    final bytes = _archiveBytes({
      'CIK0000320193.json': _facts('Apple Inc.', fy: 2025, val: 400),
    });
    final progress = await repoServing(bytes).ingest().toList();

    final downloading = progress.whereType<IngestDownloading>().last;
    expect(downloading.receivedBytes, bytes.length);
    expect(downloading.fraction, 1.0);
  });

  test('creates the staging directory when it does not exist', () async {
    // getTemporaryDirectory() on macOS returns a path inside the sandbox
    // container that has not necessarily been created yet, and openWrite does
    // not create parents.
    final missing = Directory('${workingDirectory.path}/not-created-yet');
    expect(missing.existsSync(), isFalse);

    final repo = BulkIngestRepo(
      workingDirectory: missing,
      client: MockClient((request) async {
        if (request.url.path.contains('financial-statement-data-sets')) {
          return http.Response('', 404);
        }
        if (request.url.toString() == tickerDirectoryUrl) {
          return http.Response(
            jsonEncode({
              '0': {'cik_str': 320193, 'ticker': 'AAPL', 'title': 'Apple Inc.'},
            }),
            200,
          );
        }
        return http.Response.bytes(
          _archiveBytes({
            'CIK0000320193.json': _facts('Apple Inc.', fy: 2025, val: 400),
          }),
          200,
        );
      }),
    );

    await repo.ingest().drain<void>();
    expect(await database.companyFor('0000320193'), isNotNull);
  });

  test('fails loudly when the archive decodes to nothing', () async {
    final repo = BulkIngestRepo(
      workingDirectory: workingDirectory,
      client: MockClient((request) async {
        if (request.url.path.contains('financial-statement-data-sets')) {
          return http.Response('', 404);
        }
        if (request.url.toString() == tickerDirectoryUrl) {
          return http.Response(
            jsonEncode({
              '0': {'cik_str': 320193, 'ticker': 'AAPL', 'title': 'Apple Inc.'},
            }),
            200,
          );
        }
        // Not a zip at all.
        return http.Response.bytes(utf8.encode('nonsense'), 200);
      }),
    );

    // A corrupt download decodes to an empty archive instead of throwing, so
    // an empty result has to be treated as a failure rather than recorded.
    await expectLater(
      repo.ingest().drain<void>(),
      throwsA(isA<FormatException>()),
    );
    expect(await database.lastIngest(), isNull);
    // And the unusable archive is cleared up rather than reused.
    await _settleCleanup();
    expect(workingDirectory.listSync(), isEmpty);
  });

  test(
    'reuses an archive already on disk instead of downloading again',
    () async {
      final archive = _archiveBytes({
        'CIK0000320193.json': _facts('Apple Inc.', fy: 2025, val: 400),
      });
      // Left behind by an attempt that downloaded but failed to load.
      File('${workingDirectory.path}/companyfacts.zip')
          .writeAsBytesSync(archive);

      var archiveRequests = 0;
      final repo = BulkIngestRepo(
        workingDirectory: workingDirectory,
        client: MockClient((request) async {
          if (request.url.toString() == tickerDirectoryUrl) {
            return http.Response(
              jsonEncode({
                '0': {
                  'cik_str': 320193,
                  'ticker': 'AAPL',
                  'title': 'Apple Inc.',
                },
              }),
              200,
            );
          }
          // Only a GET of the archive itself is a download; the ingest also
          // HEADs it for the date and GETs the optional sector data sets.
          if (request.method == 'GET' &&
              request.url.toString() == bulkCompanyFactsUrl) {
            archiveRequests++;
          }
          return http.Response.bytes(archive, 200);
        }),
      );

      final progress = await repo.ingest().toList();

      expect(archiveRequests, 0, reason: 'the 1.4 GB download was repeated');
      expect(progress.whereType<IngestDownloading>(), isEmpty);
      expect(await database.companyFor('0000320193'), isNotNull);
    },
  );

  test('a half-written download never looks complete', () async {
    final repo = BulkIngestRepo(
      workingDirectory: workingDirectory,
      client: MockClient((request) async {
        if (request.url.path.contains('financial-statement-data-sets')) {
          return http.Response('', 404);
        }
        if (request.url.toString() == tickerDirectoryUrl) {
          return http.Response(
            jsonEncode({
              '0': {'cik_str': 320193, 'ticker': 'AAPL', 'title': 'Apple Inc.'},
            }),
            200,
          );
        }
        return http.Response.bytes(const [1, 2, 3], 500);
      }),
    );

    await expectLater(repo.ingest().drain<void>(), throwsA(anything));
    await _settleCleanup();
    // Nothing under the final name, so a retry downloads afresh.
    expect(
      File('${workingDirectory.path}/companyfacts.zip').existsSync(),
      isFalse,
    );
    expect(workingDirectory.listSync(), isEmpty);
  });

  test('leaves no archive behind on disk', () async {
    await repoServing(
      _archiveBytes({
        'CIK0000320193.json': _facts('Apple Inc.', fy: 2025, val: 400),
      }),
    ).ingest().drain<void>();

    await _settleCleanup();
    expect(workingDirectory.listSync(), isEmpty);
  });
}
