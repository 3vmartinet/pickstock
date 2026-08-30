import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/sec/bulk_ingest_repo.dart';

BulkIngestRepo get _bulkIngestRepo => GetIt.I.get<BulkIngestRepo>();

/// Drives the one-off bulk download that populates the local database.
class IngestViewModel extends ChangeNotifier {
  IngestProgress? _progress;

  /// `null` until an ingest has been started this session.
  IngestProgress? get progress => _progress;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  bool _hasFailed = false;
  bool get hasFailed => _hasFailed;

  /// Starts the ingest, ignoring a second request while one is in flight.
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _hasFailed = false;
    _progress = const IngestDownloading(receivedBytes: 0, totalBytes: null);
    notifyListeners();

    try {
      await for (final progress in _bulkIngestRepo.ingest()) {
        _progress = progress;
        notifyListeners();
      }
    } on Object catch (error) {
      logSevere(() => 'Bulk ingest failed: $error');
      _hasFailed = true;
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }
}
