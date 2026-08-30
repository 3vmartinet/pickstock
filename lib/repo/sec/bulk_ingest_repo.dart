import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/sec/company_facts_parser.dart';

AppDatabase get _database => GetIt.I.get<AppDatabase>();

/// SEC's bulk archive of every filer's XBRL company facts. One request in
/// place of twenty thousand, which is what their fair-use guidance asks for.
const String bulkCompanyFactsUrl =
    'https://www.sec.gov/Archives/edgar/daily-index/xbrl/companyfacts.zip';

/// EDGAR requires a descriptive User-Agent on every request.
const String _userAgent = 'PickStock App straspool+pickstock@gmail.com';

const String _archiveFileName = 'companyfacts.zip';
const String _cikFilePrefix = 'CIK';
const String _jsonSuffix = '.json';
const int _cikDigits = 10;
const String _cikPadding = '0';

/// Rows per transaction. Large enough that the ~20,000 companies do not cost
/// twenty thousand transactions, small enough to bound memory.
const int _batchSize = 2000;

/// How far along a bulk ingest is.
sealed class IngestProgress {
  const IngestProgress();
}

final class IngestDownloading extends IngestProgress {
  const IngestDownloading({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;

  /// `null` when the server sends no content length.
  final int? totalBytes;

  double? get fraction => totalBytes == null || totalBytes == 0
      ? null
      : receivedBytes / totalBytes!;
}

final class IngestParsing extends IngestProgress {
  const IngestParsing({required this.companiesRead});

  final int companiesRead;
}

final class IngestDone extends IngestProgress {
  const IngestDone({required this.companyCount});

  final int companyCount;
}

/// Downloads SEC's bulk company facts archive and loads it into the database.
class BulkIngestRepo {
  BulkIngestRepo({http.Client? client, this.workingDirectory})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Where the archive is staged. Overridden by tests; otherwise the platform
  /// temporary directory.
  final Directory? workingDirectory;

  /// Runs a full ingest, replacing whatever is already stored.
  ///
  /// The archive is ~1.4 GB and expands to roughly 19 GB of JSON, so it is
  /// streamed to disk and then read one entry at a time — never held whole in
  /// memory.
  Stream<IngestProgress> ingest() async* {
    final stagingDirectory = workingDirectory ?? await getTemporaryDirectory();
    final archiveFile = File('${stagingDirectory.path}/$_archiveFileName');

    yield* _download(archiveFile);
    yield* _load(archiveFile);

    // The archive is a large temporary; it is of no use once loaded.
    if (archiveFile.existsSync()) await archiveFile.delete();
  }

  Stream<IngestProgress> _download(File target) async* {
    logInfo(() => 'Downloading $bulkCompanyFactsUrl');
    final request = http.Request('GET', Uri.parse(bulkCompanyFactsUrl))
      ..headers['User-Agent'] = _userAgent;
    final response = await _client.send(request);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Bulk download failed: ${response.statusCode}');
    }

    final sink = target.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        yield IngestDownloading(
          receivedBytes: received,
          totalBytes: response.contentLength,
        );
      }
    } finally {
      await sink.close();
    }
  }

  Stream<IngestProgress> _load(File archiveFile) async* {
    logInfo(
      () => 'Loading ${archiveFile.lengthSync()} bytes into the database',
    );
    await _database.clearFinancials();

    final input = InputFileStream(archiveFile.path);
    final archive = ZipDecoder().decodeStream(input);

    var companyCount = 0;
    var companyBatch = <CompaniesCompanion>[];
    var yearBatch = <FiscalYearsCompanion>[];

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final cik = _cikOf(entry.name);
      if (cik == null) continue;

      final Map<String, dynamic> facts;
      try {
        facts =
            jsonDecode(utf8.decode(entry.readBytes()!)) as Map<String, dynamic>;
      } on Object catch (error) {
        // One malformed filer should not abandon the other twenty thousand.
        logWarning(() => 'Skipping ${entry.name}: $error');
        continue;
      }

      final years = CompanyFactsParser.parse(facts);
      if (years.isEmpty) continue;

      companyBatch.add(
        CompaniesCompanion.insert(
          cik: cik,
          name: CompanyFactsParser.entityName(facts) ?? cik,
        ),
      );
      for (final year in years) {
        yearBatch.add(
          FiscalYearsCompanion.insert(
            cik: cik,
            fiscalYear: year.fiscalYear,
            revenue: Value(year.revenue),
            netIncome: Value(year.netIncome),
            operatingCashFlow: Value(year.operatingCashFlow),
            capitalExpenditure: Value(year.capitalExpenditure),
            totalDebt: Value(year.totalDebt),
            cash: Value(year.cash),
          ),
        );
      }
      companyCount++;

      if (companyBatch.length >= _batchSize) {
        await _flush(companyBatch, yearBatch);
        companyBatch = [];
        yearBatch = [];
        yield IngestParsing(companiesRead: companyCount);
      }
    }

    await _flush(companyBatch, yearBatch);
    await _database.recordIngest(companyCount);
    logInfo(() => 'Ingested $companyCount companies');
    yield IngestDone(companyCount: companyCount);
  }

  Future<void> _flush(
    List<CompaniesCompanion> companies,
    List<FiscalYearsCompanion> years,
  ) async {
    if (companies.isEmpty) return;
    await _database.batch((batch) {
      batch.insertAll(
        _database.companies,
        companies,
        mode: InsertMode.insertOrReplace,
      );
      batch.insertAll(
        _database.fiscalYears,
        years,
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  /// `CIK0000320193.json` -> `0000320193`. Anything else is not a filer file.
  static String? _cikOf(String entryName) {
    final base = entryName.split('/').last;
    if (!base.startsWith(_cikFilePrefix) || !base.endsWith(_jsonSuffix)) {
      return null;
    }
    final digits = base.substring(
      _cikFilePrefix.length,
      base.length - _jsonSuffix.length,
    );
    if (digits.isEmpty || int.tryParse(digits) == null) return null;
    return digits.padLeft(_cikDigits, _cikPadding);
  }
}
