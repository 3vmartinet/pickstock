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

/// Builds a zip shaped like SEC's: one `CIK##########.json` per filer.
List<int> _archiveBytes(Map<String, Map<String, dynamic>> filesByName) {
  final archive = Archive();
  filesByName.forEach((name, facts) {
    final bytes = utf8.encode(jsonEncode(facts));
    archive.add(ArchiveFile.bytes(name, bytes));
  });
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

  BulkIngestRepo repoServing(List<int> bytes) => BulkIngestRepo(
    workingDirectory: workingDirectory,
    client: MockClient((_) async => http.Response.bytes(bytes, 200)),
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

  test('reports download progress before parsing', () async {
    final bytes = _archiveBytes({
      'CIK0000320193.json': _facts('Apple Inc.', fy: 2025, val: 400),
    });
    final progress = await repoServing(bytes).ingest().toList();

    final downloading = progress.whereType<IngestDownloading>().last;
    expect(downloading.receivedBytes, bytes.length);
    expect(downloading.fraction, 1.0);
  });

  test('leaves no archive behind on disk', () async {
    await repoServing(
      _archiveBytes({
        'CIK0000320193.json': _facts('Apple Inc.', fy: 2025, val: 400),
      }),
    ).ingest().drain<void>();

    expect(workingDirectory.listSync(), isEmpty);
  });
}
