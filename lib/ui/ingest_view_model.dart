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

  /// When the stage now running began, and how far along it already was, so
  /// throughput is measured over the current stage rather than the whole run.
  DateTime? _stageStartedAt;
  num _stageStartValue = 0;
  num _stageValue = 0;
  num? _stageTotal;

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
    };

    // A new stage restarts the measurement; the previous stage's throughput
    // says nothing about this one.
    final isNewStage =
        _state is! IngestActive ||
        IngestStage.of((_state as IngestActive).progress) !=
            IngestStage.of(progress);
    if (isNewStage) {
      _stageStartedAt = DateTime.now();
      _stageStartValue = value;
    }
    _stageValue = value;
    _stageTotal = total;
  }

  bool get isRunning => _state is IngestActive;

  /// Decides whether the app can start, loading the ticker directory if so.
  Future<void> check() async {
    // Fixture mode bypasses the database entirely.
    if (usesMockData) return _setState(const IngestReady());

    final run = await _database.lastIngest();
    if (run == null) return _setState(const IngestRequired());

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
  Future<void> start() async {
    if (isRunning) return;
    _stageStartedAt = null;
    _setState(const IngestActive(IngestFetchingDirectory()));

    try {
      await for (final progress in _bulkIngestRepo.ingest()) {
        _trackProgress(progress);
        _setState(IngestActive(progress));
      }
      await _tickerDirectoryRepo.load();
      // Freshly loaded, so nothing newer is on offer.
      final run = await _database.lastIngest();
      _loadedArchiveDate = run?.archiveLastModified;
      _availableArchiveDate = _loadedArchiveDate;
      _setState(const IngestReady());
    } on Object catch (error) {
      logSevere(() => 'Bulk ingest failed: $error');
      _setState(const IngestFailed());
    }
  }

  /// Asks SEC whether a newer archive exists. One HEAD request, run after the
  /// app is already usable so it never delays the first frame.
  Future<void> _checkForNewerArchive(DateTime? loaded) async {
    _loadedArchiveDate = loaded;
    _availableArchiveDate = await _bulkIngestRepo.fetchArchiveLastModified();
    notifyListeners();
  }

  void _setState(IngestState state) {
    _state = state;
    notifyListeners();
  }
}
