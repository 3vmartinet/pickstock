import 'package:flutter/widgets.dart';
import 'package:pickstock/data/snapshot/ingest_stage.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/dependencies_repo.dart';
import 'package:pickstock/repo/sec/bulk_ingest_repo.dart';
import 'package:pickstock/repo/sec/ticker_directory_repo.dart';

AppDatabase get _database => GetIt.I.get<AppDatabase>();
BulkIngestRepo get _bulkIngestRepo => GetIt.I.get<BulkIngestRepo>();
TickerDirectoryRepo get _tickerDirectoryRepo =>
    GetIt.I.get<TickerDirectoryRepo>();

/// Whether the app has the data it needs to show anything at all.
sealed class IngestState {
  const IngestState();
}

/// Reading the database to find out. The first frame lands here.
final class IngestChecking extends IngestState {
  const IngestChecking();
}

/// The database holds nothing usable; the bulk archive must be downloaded.
final class IngestRequired extends IngestState {
  const IngestRequired();
}

/// A download is under way. [progress] says which stage.
final class IngestActive extends IngestState {
  const IngestActive(this.progress);

  final IngestProgress progress;
}

/// The download did not finish.
final class IngestFailed extends IngestState {
  const IngestFailed();
}

/// Data is loaded and the app can be used.
final class IngestReady extends IngestState {
  const IngestReady();
}

/// Where the optional refresh has got to.
///
/// Kept apart from [IngestState] because a refresh is two steps with very
/// different demands: the downloads touch nothing and run behind a working
/// app, while loading them clears the tables and has to block it.
///
/// An enum rather than a state object carrying progress: the only thing
/// watching a background download is one app-bar button, and a value that
/// changed on every network chunk would rebuild the app bar hundreds of times
/// a second.
enum UpdatePhase {
  /// Nothing newer is on offer — or the check has not run yet.
  none,

  /// SEC has rebuilt the archive; the download has not been asked for.
  offered,

  /// Downloading, with the app still usable.
  downloading,

  /// Downloaded and waiting for the go-ahead to touch the database.
  staged,

  /// The download did not finish. Nothing was written, so what is already
  /// loaded is untouched.
  failed,
}

/// Below this the average is too noisy to show, and dividing by it produces
/// silly estimates.
const Duration _minimumSampleWindow = Duration(seconds: 2);

/// Owns the one-off bulk download and, with it, whether the app is usable.
///
/// The app is gated on this: every screen needs the database, so there is no
/// meaningful partial state to show.
class IngestViewModel extends ChangeNotifier {
  IngestViewModel() {
    check();
  }

  IngestState _state = const IngestChecking();
  IngestState get state => _state;

  UpdatePhase _updatePhase = UpdatePhase.none;
  UpdatePhase get updatePhase => _updatePhase;

  /// The download waiting to be loaded, held between the two steps of a
  /// refresh. Only ever set while [updatePhase] is [UpdatePhase.staged].
  ///
  /// A handle to files on disk, so this survives the app being closed: a
  /// download finished last night is picked up by [check] this morning.
  StagedIngest? _staged;

  /// How far a background download has got, in whole percent, or `null` where
  /// the stage cannot be measured. Whole percent so listeners hear from a
  /// 1.4 GB download a hundred times rather than thousands.
  int? _updatePercent;
  int? get updatePercent => _updatePercent;

  /// The same figure as a fraction, which is what a progress bar takes.
  double? get updateFraction {
    final percent = _updatePercent;
    return percent == null ? null : percent / _percent;
  }

  /// Set when the user asks to stop. The download loop drops out at its next
  /// report, and the stream's own clean-up deletes what had come down.
  bool _cancelDownload = false;

  /// When the stage now running began, and how far along it already was, so
  /// throughput is measured over the current stage rather than the whole run.
  DateTime? _stageStartedAt;
  num _stageStartValue = 0;
  num _stageValue = 0;
  num? _stageTotal;

  /// The last report seen on whichever run is under way, so a stage change can
  /// be spotted without consulting the state a run does not own.
  IngestProgress? _lastProgress;

  DateTime? _availableArchiveDate;
  DateTime? _loadedArchiveDate;

  /// Whether SEC has rebuilt the archive since the loaded one.
  ///
  /// False until the check has run, so no refresh is offered on the strength
  /// of not knowing.
  bool get isUpdateAvailable {
    final available = _availableArchiveDate;
    final loaded = _loadedArchiveDate;
    if (available == null || loaded == null) return false;
    return available.isAfter(loaded);
  }

  /// When SEC last rebuilt the archive now on offer.
  DateTime? get availableArchiveDate => _availableArchiveDate;

  /// When SEC rebuilt the archive the database was built from, or `null` if
  /// the ingest that loaded it did not record one.
  DateTime? get loadedArchiveDate => _loadedArchiveDate;

  /// How long the last database load took, or `null` if none has been timed.
  ///
  /// The archive and the machine are much the same from one refresh to the
  /// next, so this is the honest answer to "how long will the app be shut?" —
  /// far better than a guessed range, and the app says as much when it has
  /// nothing to go on.
  Duration? get lastLoadDuration => _lastLoadDuration;
  Duration? _lastLoadDuration;

  /// Units per second through the current stage: bytes while downloading,
  /// companies while loading. `null` until there is enough to average over.
  double? get ratePerSecond {
    final startedAt = _stageStartedAt;
    if (startedAt == null) return null;
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < _minimumSampleWindow) return null;
    final done = _stageValue - _stageStartValue;
    if (done <= 0) return null;
    return done / elapsed.inMilliseconds * Duration.millisecondsPerSecond;
  }

  /// How much longer the current stage should take, at the rate so far.
  Duration? get estimatedRemaining {
    final rate = ratePerSecond;
    final total = _stageTotal;
    if (rate == null || total == null) return null;
    final left = total - _stageValue;
    if (left <= 0) return Duration.zero;
    return Duration(seconds: (left / rate).round());
  }

  void _trackProgress(IngestProgress progress) {
    final (value, total) = switch (progress) {
      IngestFetchingDirectory() => (0 as num, null),
      IngestFetchingSectors(:final quartersRead) => (
        quartersRead as num,
        sectorQuarters as num,
      ),
      IngestDownloading(:final receivedBytes, :final totalBytes) => (
        receivedBytes as num,
        totalBytes as num?,
      ),
      IngestLoading(:final companiesLoaded, :final totalCompanies) => (
        companiesLoaded as num,
        totalCompanies as num,
      ),
      IngestDone(:final companyCount) => (companyCount as num, companyCount),
      // Not a stage of its own, and not measurable: the hand-off between the
      // two halves of an ingest.
      IngestStaged() => (0 as num, null),
    };

    // A new stage restarts the measurement; the previous stage's throughput
    // says nothing about this one.
    final previous = _lastProgress;
    final isNewStage =
        previous == null ||
        IngestStage.of(previous) != IngestStage.of(progress);
    if (isNewStage) {
      _stageStartedAt = DateTime.now();
      _stageStartValue = value;
    }
    _lastProgress = progress;
    _stageValue = value;
    _stageTotal = total;
  }

  bool get isRunning => _state is IngestActive;

  /// Whether anything is under way, blocking or not, so neither step of a
  /// refresh can be started on top of the other.
  bool get _isBusy => isRunning || _updatePhase == UpdatePhase.downloading;

  /// Decides whether the app can start, loading the ticker directory if so.
  Future<void> check() async {
    // Fixture mode bypasses the database entirely.
    if (usesMockData) return _setState(const IngestReady());

    final run = await _database.lastIngest();
    if (run == null) return _setState(const IngestRequired());
    _lastLoadDuration = _durationOf(run);

    await _tickerDirectoryRepo.load();
    _setState(
      _tickerDirectoryRepo.isLoaded
          ? const IngestReady()
          : const IngestRequired(),
    );

    if (_state is IngestReady) {
      await _checkForNewerArchive(run.archiveLastModified);
    }
  }

  /// Downloads the archive and loads it, then reopens the app.
  ///
  /// Both halves in one blocking pass: this is the first run, or a retry after
  /// one failed, and either way there is no data behind the gate to use.
  Future<void> start() async {
    if (_isBusy) return;
    _beginRun();
    _setState(const IngestActive(IngestFetchingDirectory()));

    try {
      await for (final progress in _bulkIngestRepo.ingest()) {
        _trackProgress(progress);
        _setState(IngestActive(progress));
      }
      await _finishRun();
      _setState(const IngestReady());
    } on Object catch (error) {
      logSevere(() => 'Bulk ingest failed: $error');
      _setState(const IngestFailed());
    }
  }

  /// Fetches everything a refresh needs without blocking the app.
  ///
  /// The downloads are 1.4 GB over several minutes and touch no table, so
  /// there is no reason to sit in front of a progress screen for them. The
  /// step that does clear the database is [applyUpdate], on a separate press.
  Future<void> downloadUpdate() async {
    if (_isBusy || !isUpdateAvailable) return;
    _beginRun();
    _updatePercent = null;
    _cancelDownload = false;
    _setUpdatePhase(UpdatePhase.downloading);

    try {
      await for (final progress in _bulkIngestRepo.download()) {
        // Checked before the report is looked at, so a cancel means a cancel
        // even in the moment the last chunk lands: pressing stop and being
        // handed a finished download instead reads as the button not working.
        // Leaving the loop cancels the stream, whose clean-up deletes the
        // part-finished download on the way out.
        if (_cancelDownload) break;
        if (progress case IngestStaged(:final staged)) {
          _staged = staged;
          break;
        }
        _trackProgress(progress);
        _reportUpdatePercent(progress);
      }

      if (_staged != null) return _setUpdatePhase(UpdatePhase.staged);
      await _abandonDownload();
    } on Object catch (error) {
      // Nothing was written, so the data already loaded is still good.
      logSevere(() => 'Update download failed: $error');
      _staged = null;
      _setUpdatePhase(UpdatePhase.failed);
    }
  }

  /// Stops a background download.
  ///
  /// A cancel rather than a pause: an archive is only useful whole, and there
  /// is no resuming a part of one, so what has come down is thrown away.
  void cancelDownload() {
    if (_updatePhase != UpdatePhase.downloading) return;
    _cancelDownload = true;
  }

  /// Puts things back as they were before a cancelled download started.
  Future<void> _abandonDownload() async {
    // Not redundant with the stream's own clean-up: a cancel that lands on the
    // very last event stops a download the stream considers finished, and a
    // finished one is the one case it deliberately leaves on disk.
    await _bulkIngestRepo.discardStaged();
    _updatePercent = null;
    _setUpdatePhase(isUpdateAvailable ? UpdatePhase.offered : UpdatePhase.none);
  }

  /// Loads what [downloadUpdate] fetched, with the app blocked behind the
  /// usual progress screen.
  ///
  /// Blocking is not a choice: the tables are cleared before they are
  /// repopulated, so for the few minutes this takes there is nothing to show.
  Future<void> applyUpdate() async {
    final staged = _staged;
    if (staged == null || _isBusy) return;
    _beginRun();
    // A placeholder until the first real report: reading the archive's index
    // takes a moment, and the ring shows the database glyph until it arrives.
    _setState(
      const IngestActive(IngestLoading(companiesLoaded: 0, totalCompanies: 0)),
    );

    try {
      await for (final progress in _bulkIngestRepo.load(staged)) {
        _trackProgress(progress);
        _setState(IngestActive(progress));
      }
      await _finishRun();
      _setState(const IngestReady());
    } on Object catch (error) {
      logSevere(() => 'Update load failed: $error');
      // The archive may have been discarded with the failure, so the staged
      // hand-off is no longer good; recovery is a full ingest from the gate.
      _staged = null;
      _updatePhase = UpdatePhase.failed;
      _setState(const IngestFailed());
    }
  }

  /// How long [run] spent loading, or `null` for one recorded before that was
  /// measured.
  Duration? _durationOf(IngestRunRow run) {
    final seconds = run.loadSeconds;
    return seconds == null ? null : Duration(seconds: seconds);
  }

  /// Clears the throughput measurement so a new run is not averaged against
  /// the last one.
  void _beginRun() {
    _stageStartedAt = null;
    _lastProgress = null;
  }

  /// Picks up what a finished run wrote: the directory it replaced and the
  /// archive date it recorded.
  Future<void> _finishRun() async {
    await _tickerDirectoryRepo.load();
    final run = await _database.lastIngest();
    _loadedArchiveDate = run?.archiveLastModified;
    _lastLoadDuration = run == null ? null : _durationOf(run);
    _staged = null;
    // Usually nothing is left on offer, the archive just loaded being the
    // newest there is. Not always: a download staged days ago loads data SEC
    // has since rebuilt, and that offer stands rather than being papered over.
    _updatePhase = isUpdateAvailable ? UpdatePhase.offered : UpdatePhase.none;
  }

  /// Asks SEC whether a newer archive exists, and picks up a download an
  /// earlier session left staged.
  ///
  /// One HEAD request and one directory listing, both run after the app is
  /// already usable so neither delays the first frame.
  Future<void> _checkForNewerArchive(DateTime? loaded) async {
    _loadedArchiveDate = loaded;
    // The app bar says which day's data the figures come from, and that does
    // not depend on anything below, so it is worth a rebuild on its own.
    notifyListeners();

    _availableArchiveDate = await _bulkIngestRepo.fetchArchiveLastModified();
    // Offered as soon as the answer is in, rather than after the disk has been
    // looked at as well: reading the staging directory is the cheaper of the
    // two, but it should not be able to hold the offer up at all.
    if (isUpdateAvailable) _setUpdatePhase(UpdatePhase.offered);

    // A download that survived the app being closed picks up where it left
    // off, at the step it was waiting on.
    final staged = await _bulkIngestRepo.readStaged();
    if (staged == null) return;
    if (_isRedundant(staged)) return _bulkIngestRepo.discardStaged();

    _staged = staged;
    _setUpdatePhase(UpdatePhase.staged);
  }

  /// Whether a staged download would tell the database nothing it does not
  /// already know.
  ///
  /// Only a provably older archive is redundant — the leftovers of an update
  /// that went in and was not cleared up. Everything else was fetched after
  /// the database was built, so it is at worst the same data, and throwing
  /// away 1.4 GB on a suspicion is the more expensive mistake.
  bool _isRedundant(StagedIngest staged) {
    final stagedDate = staged.archiveLastModified;
    final loaded = _loadedArchiveDate;
    if (stagedDate == null || loaded == null) return false;
    return !stagedDate.isAfter(loaded);
  }

  /// Tells listeners how far a background download has got, but only when the
  /// figure they would show has actually changed: reports arrive per network
  /// chunk, which is hundreds a second.
  void _reportUpdatePercent(IngestProgress progress) {
    final percent = switch (progress) {
      IngestDownloading(:final fraction) =>
        fraction == null ? null : (fraction * _percent).round(),
      // The other stages are too short, or too small, to be worth a figure.
      _ => null,
    };
    if (percent == _updatePercent) return;
    _updatePercent = percent;
    notifyListeners();
  }

  void _setUpdatePhase(UpdatePhase phase) {
    _updatePhase = phase;
    notifyListeners();
  }

  void _setState(IngestState state) {
    _state = state;
    notifyListeners();
  }
}

/// A fraction as a percentage.
const int _percent = 100;
