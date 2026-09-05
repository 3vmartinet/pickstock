// Not a test but a stopwatch, which is why it has no `_test` suffix and so
// never runs with the suite. It exists because the width a load should run at
// is a property of the machine, and guessing it was wrong once already: the
// obvious answer — one worker per spare core — turned out to be half the speed
// of four workers on a twelve-core machine.
//
// Run it on a machine whose numbers are not known, a laptop with fewer cores
// say, and if the curve peaks somewhere other than four then that is what
// `_maxParseWorkers` should say.
//
//   fvm flutter test test/ingest_benchmark.dart -r expanded
//
// The synthetic archive is built once and cached; deleting it forces a rebuild,
// which takes a couple of minutes.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/sec/bulk_ingest_repo.dart';

const int _filers = 3000;

/// Real filings carry hundreds of tags, of which the parser reads about
/// thirty; the rest still has to be decoded to get past it.
const int _tags = 100;
final String _cache = '${Directory.systemTemp.path}/pickstock-ingest-benchmark';

/// Roughly the shape and size of a real filer payload: fifteen tags, a decade
/// of annuals and the quarters between them.
Map<String, dynamic> _facts(int cik) {
  List<Map<String, dynamic>> series(num base) => [
    for (var year = 2025; year > 2013; year--)
      for (final period in const ['FY', 'Q1', 'Q2', 'Q3'])
        {
          'accn': '0000320193-$year-000${period.hashCode.abs() % 100}',
          'fy': year,
          'fp': period,
          'form': period == 'FY' ? '10-K' : '10-Q',
          'start': '${year - 1}-10-01',
          'end': '$year-09-30',
          'filed': '$year-11-01',
          'frame': 'CY$year',
          'val': base + year,
        },
  ];

  const read = [
    'RevenueFromContractWithCustomerExcludingAssessedTax',
    'Revenues',
    'NetIncomeLoss',
    'ProfitLoss',
    'NetCashProvidedByUsedInOperatingActivities',
    'PaymentsToAcquirePropertyPlantAndEquipment',
    'OperatingIncomeLoss',
    'Assets',
    'StockholdersEquity',
    'LongTermDebtNoncurrent',
    'CashAndCashEquivalentsAtCarryingValue',
    'ShareBasedCompensation',
    'PaymentsOfDividendsCommonStock',
    'PaymentsForRepurchaseOfCommonStock',
    'InterestExpense',
  ];

  return {
    'cik': cik,
    'entityName': 'Filer number $cik Incorporated',
    'facts': {
      'us-gaap': {
        for (final tag in read)
          tag: {
            'units': {'USD': series(cik.toDouble())},
          },
        for (var filler = read.length; filler < _tags; filler++)
          'IgnoredConceptNumber$filler': {
            'units': {'USD': series(cik.toDouble())},
          },
      },
    },
  };
}

Future<File> _archive() async {
  Directory(_cache).createSync(recursive: true);
  final file = File('$_cache/companyfacts.zip');
  if (file.existsSync()) return file;

  // One entry at a time, so a 2 GB archive is never held in memory to build.
  final encoder = ZipEncoder()..startEncode(OutputFileStream(file.path));
  for (var index = 0; index < _filers; index++) {
    encoder.add(
      ArchiveFile.bytes(
        'CIK${(100000 + index).toString().padLeft(10, '0')}.json',
        utf8.encode(jsonEncode(_facts(100000 + index))),
      ),
    );
  }
  encoder.endEncode();
  return file;
}

void main() {
  test('how long a load takes', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final archive = await _archive();
    stdout.writeln(
      'archive: ${(archive.lengthSync() / 1e6).toStringAsFixed(0)} MB '
      'of $_filers filers on ${Platform.numberOfProcessors} cores',
    );

    final indices = <int>[];
    final input = InputFileStream(archive.path);
    final decoded = ZipDecoder().decodeStream(input);
    for (var index = 0; index < decoded.length; index++) {
      indices.add(index);
    }
    input.closeSync();

    List<List<int>> sliced(int size) => [
      for (var start = 0; start < indices.length; start += size)
        indices.sublist(
          start,
          start + size > indices.length ? indices.length : start + size,
        ),
    ];

    // Parsing alone, with no database in the way, at a bounded width.
    Future<int> parseOnly(int width, int sliceSize) async {
      final slices = sliced(sliceSize);
      var next = 0;
      var parsed = 0;
      Future<void> worker() async {
        while (true) {
          if (next >= slices.length) return;
          final slice = slices[next++];
          final read = await Isolate.run(
            () => parseArchiveSlice(archive.path, slice),
          );
          parsed += read.length;
        }
      }

      await Future.wait([for (var i = 0; i < width; i++) worker()]);
      return parsed;
    }

    for (final width in const [1, 2, 3, 4, 6, 8]) {
      final started = DateTime.now();
      final parsed = await parseOnly(width, width == 1 ? 150 : 64);
      stdout.writeln(
        'parse only  ${width.toString().padLeft(2)}-wide   '
        '${DateTime.now().difference(started).inMilliseconds}ms  '
        '($parsed filers)',
      );
    }

    for (final workers in const [1, 2, 3, 4, 6, 8]) {
      final directory = await Directory.systemTemp.createTemp('bench');
      final database = AppDatabase.forTesting(
        NativeDatabase(File('${directory.path}/db.sqlite')),
      );
      await GetIt.I.reset();
      GetIt.I.registerSingleton<AppDatabase>(database);

      final staging = Directory('${directory.path}/sec-download')
        ..createSync(recursive: true);
      archive.copySync('${staging.path}/companyfacts.zip');
      File('${staging.path}/company_tickers.json').writeAsStringSync('{}');
      File('${staging.path}/sectors.json').writeAsStringSync('{}');
      File('${staging.path}/staged.json').writeAsStringSync(
        jsonEncode({
          'archiveBytes': File('${staging.path}/companyfacts.zip').lengthSync(),
        }),
      );

      final repo = BulkIngestRepo(
        workingDirectory: directory,
        parseWorkers: workers,
      );
      final staged = await repo.readStaged();
      final started = DateTime.now();
      final progress = await repo.load(staged!).toList();
      final took = DateTime.now().difference(started).inMilliseconds;
      stdout.writeln(
        'full load   ${workers.toString().padLeft(2)} workers  ${took}ms  '
        '(${(progress.last as IngestDone).companyCount} filers)',
      );

      await database.close();
      await directory.delete(recursive: true);
    }
    await GetIt.I.reset();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
