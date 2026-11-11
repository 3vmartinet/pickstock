import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/research/framework_score.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/price_repo.dart';
import 'package:pickstock/repo/quote/bulk_price_refresh.dart';
import 'package:pickstock/repo/research/research_note_repo.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';
import 'package:pickstock/repo/sec/ticker_directory_repo.dart';
import 'package:pickstock/ui/report/research_queue.dart';

ResearchNoteRepo get _noteRepo => GetIt.I.get<ResearchNoteRepo>();
ResearchQueue get _researchQueue => GetIt.I.get<ResearchQueue>();
SecRepo get _secRepo => GetIt.I.get<SecRepo>();
PriceRepo get _priceRepo => GetIt.I.get<PriceRepo>();
TickerDirectoryRepo get _directory => GetIt.I.get<TickerDirectoryRepo>();
BulkPriceRefresh get _bulkPrices => GetIt.I.get<BulkPriceRefresh>();

/// The framework score of every company that has been through it, for the
/// list's tiles.
///
/// The same score the company's report shows, settled the same way: the
/// answers on file, read against the filings and the stored price as they
/// are now by [FrameworkScore.settle]. Reading only the verdicts filed would
/// leave a tile at the price and the year of the day the model was asked,
/// while the report beside it moved on.
///
/// Read in one pass over the stored answers rather than per tile, and read
/// again whenever a framework run in the research queue moves on, which is
/// when an answer can have been filed or cleared, and whenever the day's
/// closes land, which moves every timing verdict at once.
class FrameworkScoresViewModel extends ChangeNotifier {
  FrameworkScoresViewModel() {
    _researchQueue.addListener(_onQueueChanged);
    if (GetIt.I.isRegistered<BulkPriceRefresh>()) {
      _bulkPrices.addListener(_onPricesChanged);
    }
    unawaited(_load());
  }

  Map<String, FrameworkScore> _scores = const {};

  /// The score for [cik], or `null` if no question has been answered for it.
  FrameworkScore? scoreFor(String cik) => _scores[cik];

  /// What the framework tasks in the queue looked like at the last load: a
  /// change to it is an answer filed, or a run started that is about to
  /// replace some.
  String _queueSignature = '';

  /// The figures each company's answers are settled against, kept across
  /// loads: they only change when an update replaces the archive, and a
  /// load comes with every step of every run.
  ///
  /// `null` for a company the archive has no figures for, so it is not
  /// asked about again on every load.
  final Map<String, FinancialSnapshot?> _snapshots = {};

  /// The directory's revision when [_snapshots] were read; a reload of the
  /// directory is an update having landed, and the figures with it.
  int? _snapshotsRevision;

  bool _isLoading = false;
  bool _loadAgain = false;
  bool _isDisposed = false;

  void _onQueueChanged() {
    final signature = [
      for (final task in _researchQueue.tasks)
        if (task.isFramework) '${task.id}:${task.stepsDone}:${task.state.name}',
    ].join(',');
    if (signature == _queueSignature) return;
    _queueSignature = signature;
    unawaited(_load());
  }

  void _onPricesChanged() {
    if (_isDisposed) return;
    unawaited(_load());
  }

  /// Reads every company's figures again, after an update has replaced
  /// them.
  Future<void> reloadFigures() {
    _snapshots.clear();
    return _load();
  }

  /// Takes the report's [score] for [cik] as the tile's own.
  ///
  /// The report settles at the price on screen, which can be newer than the
  /// one stored when a quote has only just arrived. Without this, a tile
  /// would show the report's score while selected and fall back to an older
  /// one the moment another tile was picked, until the next load.
  void adopt(String cik, FrameworkScore score) {
    if (_isDisposed || _scores[cik] == score) return;
    _scores = {..._scores, cik: score};
    notifyListeners();
  }

  Future<void> _load() async {
    // One load at a time; a change during it is picked up by one more.
    if (_isLoading) {
      _loadAgain = true;
      return;
    }
    _isLoading = true;
    try {
      do {
        _loadAgain = false;
        final scores = await _read();
        if (_isDisposed) return;
        if (!const MapEquality().equals(scores, _scores)) {
          _scores = scores;
          notifyListeners();
        }
      } while (_loadAgain && !_isDisposed);
    } on Object catch (error) {
      logWarning(() => 'Could not read the framework answers: $error');
    } finally {
      _isLoading = false;
    }
  }

  Future<Map<String, FrameworkScore>> _read() async {
    final notes = await _noteRepo.bodiesOfKind('$frameworkNoteKind.');
    final answers = <String, Map<FrameworkQuestion, FrameworkAnswer>>{};
    for (final (:cik, :kind, :body) in notes) {
      final question = FrameworkQuestion.fromNoteKind(kind);
      if (question == null || body == null) continue;
      final answer = FrameworkAnswer.fromJson(_decoded(body));
      // A note that cannot be read is a question not yet answered, as the
      // report treats it.
      if (answer == null) continue;
      answers.putIfAbsent(cik, () => {})[question] = answer;
    }

    if (_snapshotsRevision != _directory.revision) {
      _snapshots.clear();
      _snapshotsRevision = _directory.revision;
    }
    final companies = {
      for (final company in _directory.allCompanies) company.cik: company,
    };

    final scores = <String, FrameworkScore>{};
    for (final MapEntry(key: cik, value: filed) in answers.entries) {
      final snapshot = await _snapshotFor(cik, companies[cik]);
      final price = (await _priceRepo.priceFor(cik))?.pricePerShare;
      scores[cik] = FrameworkScore.settle(
        filed,
        snapshot: snapshot,
        valuation: snapshot == null || price == null || price <= 0
            ? null
            : Valuation(snapshot: snapshot, pricePerShare: price),
      );
    }
    return scores;
  }

  /// The figures [cik]'s answers are settled against, or `null` where the
  /// archive has none — in which case the verdicts filed stand.
  Future<FinancialSnapshot?> _snapshotFor(String cik, Company? company) async {
    if (_snapshots.containsKey(cik)) return _snapshots[cik];
    // Not remembered as missing until the directory is there to say so.
    if (company == null) {
      if (_directory.isLoaded) _snapshots[cik] = null;
      return null;
    }
    try {
      return _snapshots[cik] = await _secRepo.fetchSnapshot(company.ticker);
    } on SecException catch (error) {
      logWarning(() => 'No figures to settle ${company.ticker} on: $error');
      return _snapshots[cik] = null;
    }
  }

  static Object? _decoded(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _researchQueue.removeListener(_onQueueChanged);
    if (GetIt.I.isRegistered<BulkPriceRefresh>()) {
      _bulkPrices.removeListener(_onPricesChanged);
    }
    super.dispose();
  }
}
