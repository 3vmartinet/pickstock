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

/// A download's own directory, under the platform temporary directory. Its
/// own, so clearing up is one recursive delete rather than a list of names to
/// remember.
const String _stagingDirectoryName = 'sec-download';

const String _archiveFileName = 'companyfacts.zip';
const String _tickersFileName = 'company_tickers.json';
const String _sectorsFileName = 'sectors.json';
const String _manifestFileName = 'staged.json';

const String _manifestArchiveDateKey = 'archiveLastModified';
const String _manifestArchiveBytesKey = 'archiveBytes';

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
    this.sharesLastFiled,
  });

  final String cik;
  final String name;
  final double? sharesOutstanding;

  /// When a share count was last put on a cover, used to tell a filer
  /// that stopped from one that never started.
  final DateTime? sharesLastFiled;
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
          sharesLastFiled: CompanyFactsParser.lastFiledShareCount(facts),
        ),
      );
    }
    return parsed;
  } finally {
    input.closeSync();
  }
}

/// SEC's ticker directory payload as rows for the `tickers` table.
List<TickersCompanion> _parseTickerDirectory(String payload) {
  final decoded = jsonDecode(payload) as Map<String, dynamic>;
  return [
    for (final raw in decoded.values)
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

/// The staged industry codes, as written by a download.
Map<String, int> _parseStagedSectors(String payload) {
  final decoded = jsonDecode(payload) as Map<String, dynamic>;
  return {for (final entry in decoded.entries) entry.key: entry.value as int};
}

/// Reads `sub.txt` out of one quarterly data set, as a SIC code per CIK.
///
/// Top-level so it can run under [Isolate.run]: the zip is about 60 MB and the
/// table inside it ten thousand lines, which is a visible stall on the isolate
/// drawing the app.
Map<String, int> readSectorCodes(Uint8List zipBytes) {
  final sicByCik = <String, int>{};
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
      sicByCik.putIfAbsent(
        cik.toString().padLeft(_cikDigits, _cikPadding),
        () => sic,
      );
    }
  }
  return sicByCik;
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

/// Every download is finished and nothing has touched the database yet.
///
/// The last event [BulkIngestRepo.download] reports, so a caller that wants
/// the two halves of an ingest apart has something to hold on to in between.
final class IngestStaged extends IngestProgress {
  const IngestStaged(this.staged);

  final StagedIngest staged;
}

/// A complete download, ready to be loaded into the database.
///
/// The two halves of an ingest are separable because only the second one
/// touches the database: fetching 1.4 GB can happen behind a working app —
/// and outlive it being closed — while loading it clears the tables and
/// cannot.
///
/// Nothing is held in memory: this is a handle to files on disk, so a download
/// finished at midnight can still be loaded the next morning.
class StagedIngest {
  const StagedIngest({
    required this.stagingDirectory,
    required this.archiveLastModified,
  });

  /// The directory holding the archive, the ticker directory, the industry
  /// codes and the manifest that vouches for all three.
  ///
  /// Owned outright and used for nothing else, so clearing up is one recursive
  /// delete that can never reach anything that matters.
  final Directory stagingDirectory;

  /// When SEC rebuilt the archive that was fetched, or `null` if the header
  /// could not be read.
  final DateTime? archiveLastModified;

  File get archiveFile => _staged(_archiveFileName);

  /// SEC's directory payload, saved verbatim.
  File get tickersFile => _staged(_tickersFileName);

  /// The merged SIC codes, as a JSON object keyed by padded CIK.
  File get sectorsFile => _staged(_sectorsFileName);

  /// Written last, and so the thing that says the other three are whole.
  File get manifestFile => _staged(_manifestFileName);

  File _staged(String name) => File('${stagingDirectory.path}/$name');
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
  /// Both halves in one pass, which is what a first run wants: there is no
  /// data to keep the app usable for anyway.
  Stream<IngestProgress> ingest() async* {
    StagedIngest? downloaded;
    // `await for`, not `yield*`: the hand-off event belongs to this function,
    // not to whoever is watching the ingest.
    await for (final progress in download()) {
      if (progress case IngestStaged(:final staged)) {
        downloaded = staged;
      } else {
        yield progress;
      }
    }
    // `download` either reports it or throws, so it cannot be missing here.
    yield* load(downloaded!);
  }

  /// Downloads everything a load needs, without touching the database.
  ///
  /// The archive is ~1.4 GB, so it is streamed to disk rather than held in
  /// memory; the ticker directory and the industry codes are saved beside it.
  /// Nothing here reads or writes the database, which is what lets a refresh
  /// run behind a working app.
  ///
  /// The final event is an [IngestStaged]; from then on the staged download
  /// belongs to the caller, which must hand it to [load].
  Stream<IngestProgress> download() async* {
    await _clearLegacyStaging();
    final staging = await _stagingDirectory();

    // A whole set from an earlier attempt — a load that failed, or the app
    // closed between the two halves — leaves nothing to fetch.
    final existing = _readStagedIn(staging);
    if (existing != null) {
      logInfo(() => 'Reusing the download already on disk');
      yield IngestStaged(existing);
      return;
    }

    // Anything else in there is half-finished, and half a download is worth
    // nothing: this starts from the beginning rather than from the middle.
    await _clearStaging(staging);
    // On macOS the sandbox container's cache directory is reported before it
    // is created, and `openWrite` does not create parents.
    await staging.create(recursive: true);

    var discardStaging = true;
    try {
      // The directory first: it is small, and a failure here should not come
      // after a 1.4 GB download.
      yield const IngestFetchingDirectory();
      // Only here for the file names it works out: the archive's date is not
      // known until the archive is down, so the whole thing is rebuilt below.
      final partial = StagedIngest(
        stagingDirectory: staging,
        archiveLastModified: null,
      );
      await partial.tickersFile.writeAsString(
        await _fetchTickerDirectory(),
        flush: true,
      );

      final sicByCik = <String, int>{};
      var quarter = 0;
      await for (final found in _fetchSectors(sicByCik)) {
        quarter = found;
        yield IngestFetchingSectors(quartersRead: found);
      }
      logInfo(
        () => 'Sectors for ${sicByCik.length} filers from $quarter data sets',
      );
      await partial.sectorsFile.writeAsString(
        jsonEncode(sicByCik),
        flush: true,
      );

      // `await for`, not `yield*`: a delegated stream's errors bypass this
      // function's catch clauses entirely, so the download would be kept when
      // it should be discarded.
      await for (final progress in _download(partial.archiveFile)) {
        yield progress;
      }

      final complete = StagedIngest(
        stagingDirectory: staging,
        // Recorded against the ingest so a later HEAD request can tell
        // whether SEC has rebuilt the archive since.
        archiveLastModified: await fetchArchiveLastModified(),
      );
      // Written last, so nothing is ever taken for a finished download until
      // it is one.
      await _writeManifest(complete);
      discardStaging = false;
      yield IngestStaged(complete);
    } finally {
      if (discardStaging) await _clearStaging(staging);
    }
  }

  /// Loads a staged download into the database, replacing what is stored.
  ///
  /// The tables are cleared before they are repopulated, so the app has
  /// nothing to show while this runs. The archive expands to roughly 19 GB of
  /// JSON and is read one entry at a time — never held whole in memory.
  Stream<IngestProgress> load(StagedIngest staged) async* {
    // Kept when a whole download failed to load for a reason other than the
    // archive itself: a retry then skips the 1.4 GB fetch.
    var discardStaging = false;
    try {
      // `await for`, not `yield*`: a delegated stream's errors bypass this
      // function's catch clauses entirely, so the download would be kept when
      // it should be discarded.
      await for (final progress in _load(staged)) {
        yield progress;
      }
      discardStaging = true;
    } on FormatException {
      // The archive is unusable, so there is nothing worth keeping.
      discardStaging = true;
      rethrow;
    } finally {
      // Everything, not just the archive: once it is in the database the
      // 1.4 GB and the two files beside it have no further use.
      if (discardStaging) await _clearStaging(staged.stagingDirectory);
    }
  }

  /// The whole download waiting on disk from an earlier session, or `null` if
  /// there is none.
  ///
  /// Anything half-finished is deleted rather than reported: the manifest is
  /// written last, so a staging directory without one is the wreckage of an
  /// interrupted download and none of it can be trusted.
  Future<StagedIngest?> readStaged() async {
    try {
      await _clearLegacyStaging();
      final staging = await _stagingDirectory();
      if (!staging.existsSync()) return null;

      final staged = _readStagedIn(staging);
      if (staged != null) return staged;

      logInfo(() => 'Discarding an unfinished download');
      await _clearStaging(staging);
      return null;
    } on Object catch (error) {
      // Not being able to look is the same as there being nothing there.
      logWarning(() => 'Could not read the staging directory: $error');
      return null;
    }
  }

  /// The download staged in [staging], or `null` if there is not a whole one.
  ///
  /// The manifest is written last and records the size the archive should be,
  /// so this is enough to tell a finished download from the wreckage of one
  /// that was interrupted — by a failure, or by the app being closed mid-way.
  StagedIngest? _readStagedIn(Directory staging) {
    final staged = StagedIngest(
      stagingDirectory: staging,
      archiveLastModified: null,
    );
    if (!staged.manifestFile.existsSync()) return null;

    try {
      final manifest = jsonDecode(
        staged.manifestFile.readAsStringSync(),
      ) as Map<String, dynamic>;
      if (!staged.tickersFile.existsSync() ||
          !staged.sectorsFile.existsSync()) {
        return null;
      }
      // A temporary directory is nobody's private property, so the archive is
      // measured rather than assumed.
      if (!staged.archiveFile.existsSync() ||
          staged.archiveFile.lengthSync() !=
              manifest[_manifestArchiveBytesKey]) {
        return null;
      }

      final date = manifest[_manifestArchiveDateKey] as String?;
      return StagedIngest(
        stagingDirectory: staging,
        archiveLastModified: date == null ? null : DateTime.parse(date),
      );
    } on Object catch (error) {
      logWarning(() => 'Could not read the staging manifest: $error');
      return null;
    }
  }

  /// Deletes a staged download, whole or not.
  Future<void> discardStaged() async {
    try {
      await _clearStaging(await _stagingDirectory());
    } on Object catch (error) {
      logWarning(() => 'Could not clear the staging directory: $error');
    }
  }

  /// Where a download is staged. Not created here: the read paths want to
  /// know whether it exists.
  Future<Directory> _stagingDirectory() async =>
      Directory('${(await _stagingRoot()).path}/$_stagingDirectoryName');

  Future<Directory> _stagingRoot() async =>
      workingDirectory ?? await getTemporaryDirectory();

  /// Deletes an archive staged by a build that kept it in the temporary
  /// directory itself, before downloads had a folder of their own.
  ///
  /// Nothing reads it any more, and 1.4 GB of orphan is not something to leave
  /// on someone's disk because the layout changed under it.
  Future<void> _clearLegacyStaging() async {
    final root = await _stagingRoot();
    for (final name in const [
      _archiveFileName,
      '$_archiveFileName$_partialSuffix',
    ]) {
      final file = File('${root.path}/$name');
      if (!file.existsSync()) continue;
      logInfo(() => 'Deleting an archive left by an earlier version');
      await _deleteQuietly(file);
    }
  }

  Future<void> _clearStaging(Directory staging) async {
    if (!staging.existsSync()) return;
    await staging.delete(recursive: true);
  }

  Future<void> _writeManifest(StagedIngest staged) async {
    final archiveDate = staged.archiveLastModified;
    await staged.manifestFile.writeAsString(
      jsonEncode({
        if (archiveDate != null)
          _manifestArchiveDateKey: archiveDate.toIso8601String(),
        _manifestArchiveBytesKey: staged.archiveFile.lengthSync(),
      }),
      flush: true,
    );
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

  /// Fetches SEC's ticker directory and hands it back verbatim, to be staged
  /// as it came.
  ///
  /// Parsed here only to fail early: an unusable directory should stop a run
  /// before the 1.4 GB download rather than after it.
  Future<String> _fetchTickerDirectory() async {
    logInfo(() => 'Fetching $tickerDirectoryUrl');
    final response = await _client.get(
      Uri.parse(tickerDirectoryUrl),
      headers: const {'User-Agent': _userAgent},
    );
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Ticker directory failed: ${response.statusCode}');
    }

    _parseTickerDirectory(response.body);
    return response.body;
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
          final bytes = response.bodyBytes;
          // Off the UI isolate: decompressing 60 MB and splitting the ten
          // thousand lines inside it stalls the app for about a second, which
          // matters when a refresh is running behind a screen still in use.
          final quarterly = await Isolate.run(() => readSectorCodes(bytes));
          // Only fill gaps: newer quarters are read first.
          for (final entry in quarterly.entries) {
            into.putIfAbsent(entry.key, () => entry.value);
          }
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

  Stream<IngestProgress> _load(StagedIngest staged) async* {
    final archiveFile = staged.archiveFile;
    logInfo(
      () => 'Loading ${archiveFile.lengthSync()} bytes into the database',
    );
    // Read back off disk rather than carried in memory, so a download staged
    // in an earlier session loads by exactly the same path as a fresh one.
    final directory = _parseTickerDirectory(
      await staged.tickersFile.readAsString(),
    );
    final sicByCik = _parseStagedSectors(
      await staged.sectorsFile.readAsString(),
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
      archiveLastModified: staged.archiveLastModified,
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
            sharesLastFiled: Value(company.sharesLastFiled),
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
