import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/research/framework_score.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/research/research_note_repo.dart';
import 'package:pickstock/ui/report/research_queue.dart';

ResearchNoteRepo get _noteRepo => GetIt.I.get<ResearchNoteRepo>();
ResearchQueue get _researchQueue => GetIt.I.get<ResearchQueue>();

/// The framework score of every company that has been through it, for the
/// list's tiles.
///
/// Read in one pass over the stored answers rather than per tile, and read
/// again whenever a framework run in the research queue moves on, which is
/// when an answer can have been filed or cleared.
class FrameworkScoresViewModel extends ChangeNotifier {
  FrameworkScoresViewModel() {
    _researchQueue.addListener(_onQueueChanged);
    unawaited(_load());
  }

  Map<String, FrameworkScore> _scores = const {};

  /// The score for [cik], or `null` if no question has been answered for it.
  FrameworkScore? scoreFor(String cik) => _scores[cik];

  /// What the framework tasks in the queue looked like at the last load: a
  /// change to it is an answer filed, or a run started that is about to
  /// replace some.
  String _queueSignature = '';

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

  static Future<Map<String, FrameworkScore>> _read() async {
    final notes = await _noteRepo.bodiesOfKind('$frameworkNoteKind.');
    final verdicts = <String, Map<FrameworkQuestion, FrameworkVerdict>>{};
    for (final (:cik, :kind, :body) in notes) {
      final question = FrameworkQuestion.fromNoteKind(kind);
      if (question == null || body == null) continue;
      final answer = FrameworkAnswer.fromJson(_decoded(body));
      // A note that cannot be read is a question not yet answered, as the
      // report treats it.
      if (answer == null) continue;
      verdicts.putIfAbsent(cik, () => {})[question] = answer.verdict;
    }
    return {
      for (final MapEntry(key: cik, value: answers) in verdicts.entries)
        cik: FrameworkScore(verdicts: answers),
    };
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
    super.dispose();
  }
}
