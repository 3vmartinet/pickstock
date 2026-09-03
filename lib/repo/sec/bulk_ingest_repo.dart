import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pickstock/data/snapshot/fiscal_quarter_figures.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/sec/company_facts_parser.dart';

AppDatabase get _database => GetIt.I.get<AppDatabase>();

/// SEC's bulk archive of every filer's XBRL company facts. One request in
/// place of twenty thousand, which is what their fair-use guidance asks for.
const String bulkCompanyFactsUrl =
    'https://www.sec.gov/Archives/edgar/daily-index/xbrl/companyfacts.zip';

/// SEC's ticker directory: 795 KB mapping symbols to CIKs. The bulk company
/// facts archive carries no symbols at all, and `submissions.zip` — the only
/// bulk file that does — is 1.5 GB, so this stays a separate small request.
const String tickerDirectoryUrl =
    'https://www.sec.gov/files/company_tickers.json';

/// EDGAR requires a descriptive User-Agent on every request.
const String _userAgent = 'PickStock App straspool+pickstock@gmail.com';

const String _archiveFileName = 'companyfacts.zip';

/// A download in flight. Renamed to [_archiveFileName] only once complete, so
/// the presence of the final name means "fully downloaded".
const String _partialSuffix = '.part';
const String _tickerKey = 'ticker';
const String _directoryCikKey = 'cik_str';
const String _titleKey = 'title';
const String _cikFilePrefix = 'CIK';
const String _jsonSuffix = '.json';
const int _cikDigits = 10;
const String _cikPadding = '0';

/// Filers handed to one background isolate at a time. Each slice is roughly
/// 150 MB of JSON — about a second of work, so the progress bar moves visibly
/// while isolate spawns stay negligible.
const int _sliceSize = 150;

/// One filer's extracted figures — small enough to hand back from a
/// background isolate, where the full payload would be wasteful to copy.
class IngestedCompany {
  const IngestedCompany({
    required this.cik,
    required this.name,
    required this.years,
    required this.quarters,
    this.sharesOutstanding,
  });

  final String cik;
  final String name;
  final double? sharesOutstanding;
  final List<FiscalYearFigures> years;
  final List<FiscalQuarterFigures> quarters;
}

/// Decompresses and parses the archive entries at [entryIndices].
///
/// Top-level so it can run under [Isolate.run]. Only the extracted figures
/// come back: about 2 KB per filer instead of the ~1 MB payload each was
/// parsed from.
List<IngestedCompany> parseArchiveSlice(
  String archivePath,
  List<int> entryIndices,
) {
  final input = InputFileStream(archivePath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final parsed = <IngestedCompany>[];

    for (final index in entryIndices) {
      final entry = archive[index];
      final cik = _cikOf(entry.name);
      if (cik == null) continue;

      final Map<String, dynamic> facts;
      try {
        facts =
            jsonDecode(utf8.decode(entry.readBytes()!)) as Map<String, dynamic>;
      } on Object catch (_) {
        // One malformed filer should not abandon the other twenty thousand.
        continue;
      }

      final years = CompanyFactsParser.parse(facts);
      if (years.isEmpty) continue;

      parsed.add(
        IngestedCompany(
          cik: cik,
          name: CompanyFactsParser.entityName(facts) ?? cik,
          years: years,
          quarters: CompanyFactsParser.parseQuarters(facts),
          sharesOutstanding: CompanyFactsParser.latestSharesOutstanding(facts),
        ),
      );
    }
    return parsed;
  } finally {
    input.closeSync();
  }
}

/// `CIK0000320193.json` -> `0000320193`. Anything else is not a filer file.
String? _cikOf(String entryName) {
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

/// How far along a bulk ingest is.
sealed class IngestProgress {
  const IngestProgress();
}

final class IngestFetchingDirectory extends IngestProgress {
  const IngestFetchingDirectory();
}

/// Industry codes are being collected from the quarterly data sets.
final class IngestFetchingSectors extends IngestProgress {
  const IngestFetchingSectors({required this.quartersRead});

  final int quartersRead;
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

/// Filers are being decompressed, parsed and written to the database.
///
/// The archive's entry count is known before any of it is decompressed, so
/// this stage reports a real fraction rather than an unbounded counter.
final class IngestLoading extends IngestProgress {
  const IngestLoading({
    required this.companiesLoaded,
    required this.totalCompanies,
  });

  final int companiesLoaded;
  final int totalCompanies;

  double? get fraction =>
      totalCompanies == 0 ? null : companiesLoaded / totalCompanies;
}

final class IngestDone extends IngestProgress {
  const IngestDone({required this.companyCount});

  final int companyCount;
}

/// SEC's quarterly financial statement data sets. Their `sub.txt` carries a
/// SIC code per filer, which is the only industry classification SEC
/// publishes — and at roughly 60 MB a quarter it is far cheaper than the only
/// other bulk file that has it (`submissions.zip`, 1.5 GB).
String sectorDatasetUrl(int year, int quarter) =>
    'https://www.sec.gov/files/dera/data/financial-statement-data-sets/'
    '${year}q$quarter.zip';

/// How many recent quarters to merge. One quarter covers only the filers who
/// reported in it; four covers nearly every active filer.
const int sectorQuarters = 4;

/// Quarters probed before giving up. The most recent is published some weeks
/// after the quarter ends, so the newest candidates are often absent.
const int _sectorQuarterProbes = 7;

const String _sectorEntryName = 'sub.txt';
const String _sectorCikColumn = 'cik';
const String _sectorSicColumn = 'sic';

/// SEC serves the archive with a `Last-Modified` header, so a HEAD request is
/// enough to learn whether a newer one is out — no need to fetch 1.4 GB to
/// find out that nothing has changed.
const String _lastModifiedHeader = 'last-modified';

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
    // On macOS the sandbox container's cache directory is reported before it
    // is created, and `openWrite` does not create parents.
    await stagingDirectory.create(recursive: true);
    final archiveFile = File('${stagingDirectory.path}/$_archiveFileName');

    // Kept only when a complete archive failed to load for a reason other
    // than the archive itself: a retry then skips the 1.4 GB download.
    var discardArchive = true;
    try {
      // The directory first: it is small, and a failure here should not come
      // after a 1.4 GB download.
      yield const IngestFetchingDirectory();
      final directory = await _fetchTickerDirectory();

      final sicByCik = <String, int>{};
      var quarter = 0;
      await for (final found in _fetchSectors(sicByCik)) {
        quarter = found;
        yield IngestFetchingSectors(quartersRead: found);
      }
      logInfo(
        () => 'Sectors for ${sicByCik.length} filers from $quarter data sets',
      );

      if (archiveFile.existsSync()) {
        // A previous attempt downloaded it and failed to load it. The file
        // takes its final name only once complete, so reusing it is safe.
        logInfo(() => 'Reusing the archive already on disk');
      } else {
        // `await for`, not `yield*`: a delegated stream's errors bypass this
        // function's catch clauses entirely, so the archive would be kept when
        // it should be discarded.
        await for (final progress in _download(archiveFile)) {
          yield progress;
        }
      }

      discardArchive = false;
      // Recorded against the ingest so a later HEAD request can tell whether
      // SEC has rebuilt the archive since.
      final archiveDate = await fetchArchiveLastModified();
      await for (final progress in _load(
        archiveFile,
        directory,
        archiveDate,
        sicByCik,
      )) {
        yield progress;
      }
      discardArchive = true;
    } on FormatException {
      // The archive is unusable, so there is nothing worth keeping.
      discardArchive = true;
      rethrow;
    } finally {
      if (discardArchive) await _deleteQuietly(archiveFile);
    }
  }

  /// When SEC last rebuilt the archive, or `null` if it cannot be determined.
  ///
  /// One HEAD request, so this is cheap enough to run on every launch.
  Future<DateTime?> fetchArchiveLastModified() async {
    try {
      final response = await _client.head(
        Uri.parse(bulkCompanyFactsUrl),
        headers: const {'User-Agent': _userAgent},
      );
      if (response.statusCode != HttpStatus.ok) return null;
      final header = response.headers[_lastModifiedHeader];
      return header == null ? null : HttpDate.parse(header);
    } on Object catch (error) {
      // Not knowing is not a failure: the app simply does not offer an update.
      logWarning(() => 'Could not read the archive date: $error');
      return null;
    }
  }

  Future<void> _deleteQuietly(File file) async {
    if (file.existsSync()) await file.delete();
  }

  Future<List<TickersCompanion>> _fetchTickerDirectory() async {
    logInfo(() => 'Fetching $tickerDirectoryUrl');
    final response = await _client.get(
      Uri.parse(tickerDirectoryUrl),
      headers: const {'User-Agent': _userAgent},
    );
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Ticker directory failed: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return [
      for (final raw in payload.values)
        if (raw case final Map<String, dynamic> entry)
          TickersCompanion.insert(
            symbol: (entry[_tickerKey] as String).toUpperCase(),
            cik: entry[_directoryCikKey].toString().padLeft(
              _cikDigits,
              _cikPadding,
            ),
            name: entry[_titleKey] as String? ?? '',
          ),
    ];
  }

  /// Merges SIC codes from the most recent quarters, newest first so a later
  /// reclassification wins.
  ///
  /// Missing quarters are normal — the newest is published weeks in arrears —
  /// so absences are skipped rather than treated as failures. Sectors are a
  /// nice-to-have: an ingest still succeeds without them.
  Stream<int> _fetchSectors(Map<String, int> into) async* {
    var found = 0;
    var candidate = DateTime.now().toUtc();

    for (var probe = 0; probe < _sectorQuarterProbes; probe++) {
      if (found >= sectorQuarters) break;
      final quarter = (candidate.month - 1) ~/ 3 + 1;
      final url = sectorDatasetUrl(candidate.year, quarter);

      try {
        final response = await _client.get(
          Uri.parse(url),
          headers: const {'User-Agent': _userAgent},
        );
        if (response.statusCode == HttpStatus.ok) {
          _readSectors(response.bodyBytes, into);
          found++;
          yield found;
        }
      } on Object catch (error) {
        logWarning(() => 'Skipping sector data set $url: $error');
      }

      // Step back one quarter.
      candidate = DateTime.utc(candidate.year, candidate.month - 3, 1);
    }
  }

  /// Reads `sub.txt` out of a data set and records each filer's SIC code.
  void _readSectors(List<int> zipBytes, Map<String, int> into) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    for (final entry in archive) {
      if (!entry.isFile || !entry.name.endsWith(_sectorEntryName)) continue;

      final lines = const LineSplitter().convert(
        utf8.decode(entry.readBytes()!, allowMalformed: true),
      );
      if (lines.isEmpty) continue;

      final columns = lines.first.split('\t');
      final cikAt = columns.indexOf(_sectorCikColumn);
      final sicAt = columns.indexOf(_sectorSicColumn);
      if (cikAt < 0 || sicAt < 0) continue;

      for (final line in lines.skip(1)) {
        final fields = line.split('\t');
        if (fields.length <= sicAt) continue;
        final sic = int.tryParse(fields[sicAt]);
        final cik = int.tryParse(fields[cikAt]);
        if (sic == null || cik == null) continue;
        // Only fill gaps: newer quarters are read first.
        into.putIfAbsent(
          cik.toString().padLeft(_cikDigits, _cikPadding),
          () => sic,
        );
      }
    }
  }

  Stream<IngestProgress> _download(File target) async* {
    logInfo(() => 'Downloading $bulkCompanyFactsUrl');
    final request = http.Request('GET', Uri.parse(bulkCompanyFactsUrl))
      ..headers['User-Agent'] = _userAgent;
    final response = await _client.send(request);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Bulk download failed: ${response.statusCode}');
    }

    final partial = File('${target.path}$_partialSuffix');
    final sink = partial.openWrite();
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
      await sink.close();
      // Named only now: a half-written file must never look complete.
      await partial.rename(target.path);
    } on Object {
      await sink.close();
      await _deleteQuietly(partial);
      rethrow;
    }
  }

  Stream<IngestProgress> _load(
    File archiveFile,
    List<TickersCompanion> directory,
    DateTime? archiveLastModified,
    Map<String, int> sicByCik,
  ) async* {
    logInfo(
      () => 'Loading ${archiveFile.lengthSync()} bytes into the database',
    );
    await _database.clearFinancials();
    await _database.batch(
      (batch) => batch.insertAll(_database.tickers, directory),
    );

    // Entry names come from the archive's central directory, so the work can
    // be counted — and non-filer entries skipped — before anything is
    // decompressed.
    final filerEntries = _filerEntryIndices(archiveFile);
    if (filerEntries.isEmpty) {
      // A truncated or corrupt download decodes to an empty archive rather
      // than throwing, so without this the ingest would be recorded as a
      // success and the app would open onto an empty database.
      throw const FormatException('The archive contained no filer payloads');
    }

    final total = filerEntries.length;
    yield IngestLoading(companiesLoaded: 0, totalCompanies: total);

    final archivePath = archiveFile.path;
    // `loaded` counts entries worked through, which is what the bar measures;
    // `stored` counts filers that actually yielded figures, which is what the
    // database holds and what the user is told at the end.
    var loaded = 0;
    var stored = 0;
    for (var start = 0; start < total; start += _sliceSize) {
      final slice = filerEntries.sublist(
        start,
        math.min(start + _sliceSize, total),
      );
      // Off the UI isolate: 19 GB of JSON takes minutes to decode, and doing
      // it here would freeze the app — progress bar included.
      final parsed = await Isolate.run(
        () => parseArchiveSlice(archivePath, slice),
      );
      await _insert(parsed, sicByCik);

      loaded += slice.length;
      stored += parsed.length;
      yield IngestLoading(companiesLoaded: loaded, totalCompanies: total);
    }

    if (stored == 0) {
      throw const FormatException('No filer in the archive could be parsed');
    }

    await _database.recordIngest(
      stored,
      archiveLastModified: archiveLastModified,
    );
    logInfo(() => 'Ingested $stored companies from $total entries');
    yield IngestDone(companyCount: stored);
  }

  /// Indices of the `CIK…json` entries, read from entry names alone.
  List<int> _filerEntryIndices(File archiveFile) {
    final input = InputFileStream(archiveFile.path);
    try {
      final archive = ZipDecoder().decodeStream(input);
      return [
        for (var index = 0; index < archive.length; index++)
          if (archive[index].isFile && _cikOf(archive[index].name) != null)
            index,
      ];
    } on Object catch (error) {
      // Garbage in place of a zip; the caller reports it as an empty archive.
      logWarning(() => 'Could not read the archive index: $error');
      return const [];
    } finally {
      input.closeSync();
    }
  }

  Future<void> _insert(
    List<IngestedCompany> parsed,
    Map<String, int> sicByCik,
  ) async {
    if (parsed.isEmpty) return;
    await _database.batch((batch) {
      batch.insertAll(_database.companies, [
        for (final company in parsed)
          CompaniesCompanion.insert(
            cik: company.cik,
            name: company.name,
            sic: Value(sicByCik[company.cik]),
            sharesOutstanding: Value(company.sharesOutstanding),
          ),
      ], mode: InsertMode.insertOrReplace);
      batch.insertAll(_database.fiscalYears, [
        for (final company in parsed)
          for (final year in company.years)
            FiscalYearsCompanion.insert(
              cik: company.cik,
              fiscalYear: year.fiscalYear,
              revenue: Value(year.revenue),
              netIncome: Value(year.netIncome),
              operatingCashFlow: Value(year.operatingCashFlow),
              capitalExpenditure: Value(year.capitalExpenditure),
              totalDebt: Value(year.totalDebt),
              cash: Value(year.cash),
              dilutedShares: Value(year.dilutedShares),
              operatingIncome: Value(year.operatingIncome),
              depreciationAmortisation: Value(year.depreciationAmortisation),
              totalAssets: Value(year.totalAssets),
              shareholdersEquity: Value(year.shareholdersEquity),
              interestExpense: Value(year.interestExpense),
            ),
      ], mode: InsertMode.insertOrReplace);
      batch.insertAll(_database.fiscalQuarters, [
        for (final company in parsed)
          for (final quarter in company.quarters)
            FiscalQuartersCompanion.insert(
              cik: company.cik,
              fiscalYear: quarter.fiscalYear,
              quarter: quarter.quarter,
              revenue: Value(quarter.revenue),
              netIncome: Value(quarter.netIncome),
              operatingCashFlow: Value(quarter.operatingCashFlow),
              capitalExpenditure: Value(quarter.capitalExpenditure),
              totalDebt: Value(quarter.totalDebt),
              cash: Value(quarter.cash),
            ),
      ], mode: InsertMode.insertOrReplace);
    });
  }
}
