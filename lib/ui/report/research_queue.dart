import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pickstock/data/research/company_insight.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/research/research_task.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/research/ollama_repo.dart';

/// One question's work, run when the queue reaches it.
///
/// Handed a way to ask whether the answer is still wanted, because the answer
/// is minutes away and the reader can change their mind in the middle of it.
/// Anything that would be written down should be behind that question.
typedef ResearchWork = Future<void> Function(bool Function() isCancelled);

/// Puts the local model's questions in a line and works through them.
///
/// One at a time, because that is what the machine can do: a 12B model
/// answering two questions at once answers both at half the speed, and on a
/// laptop it may not have the memory to try. Asking three things and having
/// them arrive one after the other is the honest version of what was going to
/// happen anyway — what was dishonest was three buttons all saying "Reading…"
/// while two of them waited.
///
/// App-level and outliving every screen: a question takes about a minute, and
/// a reader who asked it is not going to sit and watch. The row in the app
/// bar is the way back to the answer.
class ResearchQueue extends ChangeNotifier {
  final List<_Queued> _queued = [];

  int _nextId = 1;
  bool _isWorking = false;

  /// Everything asked for and not yet taken away, the most recently asked
  /// first.
  ///
  /// Newest at the top because that is the question the reader has in mind:
  /// they open the list straight after asking, or to see whether what they
  /// just asked has come back. The line is still answered oldest first — this
  /// is the order it is shown in, not the order it is worked through.
  List<ResearchTask> get tasks => [
    for (final entry in _queued.reversed) entry.task,
  ];

  /// How many answers have landed that the reader has not opened yet.
  int get unseenCount => _queued.where((entry) => entry.task.isUnseen).length;

  /// Records that [id]'s answer has been opened, which takes its dot away and
  /// counts it off the app bar's badge. The row stays, as the way back to it.
  void markSeen(int id) {
    final index = _indexOf(id);
    if (index < 0 || _queued[index].task.isSeen) return;
    _queued[index] = _queued[index].withTask(
      _queued[index].task.copyWith(isSeen: true),
    );
    notifyListeners();
  }

  /// Marks every finished question as opened, from the section's toolbar.
  void markAllSeen() {
    var changed = false;
    for (var index = 0; index < _queued.length; index++) {
      final task = _queued[index].task;
      if (!task.isUnseen) continue;
      _queued[index] = _queued[index].withTask(task.copyWith(isSeen: true));
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Whether anything has finished, answered or failed, which is what the
  /// toolbar's clearing is for.
  bool get hasFinished => _queued.any((entry) => entry.task.isFinished);

  /// Takes every finished question off the list, answered or failed, and
  /// leaves the ones still owed. The answers stay on the companies' reports.
  void clearFinished() {
    final before = _queued.length;
    _queued.removeWhere((entry) => entry.task.isFinished);
    if (_queued.length != before) notifyListeners();
  }

  /// How many questions are still owed — being answered or waiting to be.
  int get activeCount => _queued.where((entry) => entry.task.isActive).length;

  /// Whether anything is still owed, which is what the app bar's glyph says.
  bool get hasActive => activeCount > 0;

  bool get isEmpty => _queued.isEmpty;

  /// The question already asked about [cik]'s [kind], if there is one.
  ///
  /// Read by the report so a card can say "queued" or "reading" without
  /// keeping its own copy of what the queue already knows.
  ResearchTask? taskFor({required String cik, required String kind}) {
    for (final entry in _queued) {
      final task = entry.task;
      if (task.cik == cik && task.kind == kind) return task;
    }
    return null;
  }

  /// Adds a question to the end of the line and starts working if nothing is.
  ///
  /// The same question about the same company is never in the list twice. What
  /// happens to the one already there depends on whether it has been answered:
  /// one still owed stands, because a second copy would spend another minute
  /// of the machine to say the same thing; an answered one goes, because
  /// asking again means that answer is being replaced and a row pointing at it
  /// is a row pointing at nothing.
  void enqueue({
    required String cik,
    required String ticker,
    required String companyName,
    required CompanyInsight? insight,
    required ResearchWork work,
    List<FrameworkQuestion> frameworkQuestions = const [],
  }) {
    final kind =
        frameworkKind(frameworkQuestions) ?? insight?.name ?? eventsNoteKind;
    final existing = taskFor(cik: cik, kind: kind);
    if (existing != null) {
      if (existing.isActive) return;
      remove(existing.id);
    }

    _queued.add(
      _Queued(
        task: ResearchTask(
          id: _nextId++,
          cik: cik,
          ticker: ticker,
          companyName: companyName,
          insight: insight,
          frameworkQuestions: frameworkQuestions,
        ),
        work: work,
      ),
    );
    notifyListeners();
    unawaited(_work());
  }

  /// Records that the task asking [cik]'s [kind] has answered [done] of its
  /// steps.
  ///
  /// By what was asked rather than by id: the work reporting it was written
  /// before the queue gave it one.
  void setStepsDone({
    required String cik,
    required String kind,
    required int done,
  }) {
    final task = taskFor(cik: cik, kind: kind);
    if (task == null || task.stepsDone == done) return;
    final index = _indexOf(task.id);
    _queued[index] = _queued[index].withTask(task.copyWith(stepsDone: done));
    notifyListeners();
  }

  /// The framework tasks still owed for [cik], a full run and any single
  /// questions alike, in the order they were asked.
  List<ResearchTask> activeFrameworkTasksFor(String cik) => [
    for (final entry in _queued)
      if (entry.task.cik == cik &&
          entry.task.isFramework &&
          entry.task.isActive)
        entry.task,
  ];

  /// Takes a question out of the list, whether it has been asked yet or not.
  ///
  /// The one call behind the row's cross: cancelling one still waiting, and
  /// dismissing one whose answer is no longer wanted in the list. Both end the
  /// same way — the row has nothing left to say and goes.
  void remove(int id) {
    final index = _indexOf(id);
    if (index < 0) return;
    final entry = _queued.removeAt(index);
    // A question already being answered cannot be called back — the model is
    // mid-paragraph and does not take interruptions. What it can be is
    // abandoned: the queue stops waiting and moves on, and the answer, when it
    // arrives, is dropped rather than written down. The work itself winds up
    // at its next stopping point, which is why the model is not asked two
    // things at once for long.
    if (!entry.abandoned.isCompleted) entry.abandoned.complete();
    notifyListeners();
  }

  /// Whether [id] has been taken out of the list, which is how running work
  /// finds out that nobody wants what it is producing.
  bool _isGone(int id) => _indexOf(id) < 0;

  int _indexOf(int id) => _queued.indexWhere((entry) => entry.task.id == id);

  /// Works through the line until there is nothing pending left.
  ///
  /// Re-entrant by guard rather than by lock: [enqueue] calls this every time,
  /// and all but the first call finds the loop already running and leaves it
  /// to pick the new question up on its next turn.
  Future<void> _work() async {
    if (_isWorking) return;
    _isWorking = true;
    try {
      while (true) {
        final next = _firstPending();
        if (next == null) break;
        _setState(next.task.id, ResearchTaskState.running);
        await _runOne(next);
      }
    } finally {
      _isWorking = false;
    }
  }

  _Queued? _firstPending() {
    for (final entry in _queued) {
      if (entry.task.isPending) return entry;
    }
    return null;
  }

  Future<void> _runOne(_Queued entry) async {
    final id = entry.task.id;
    ResearchFailure? failure;

    // Kept as a future rather than awaited directly, so abandoning it does not
    // mean waiting for it. Its errors are caught in here rather than left to
    // escape a race nobody is watching.
    final work = () async {
      try {
        await entry.work(() => _isGone(id));
      } on ResearchException catch (error) {
        logWarning(() => 'Research task $id did not finish: $error');
        failure = error.failure;
      } on Object catch (error, trace) {
        logWarning(() => 'Research task $id did not finish: $error\n$trace');
        failure = ResearchFailure.failed;
      }
    }();

    await Future.any([work, entry.abandoned.future]);
    // Cancelled while it ran: there is no row left to put the outcome in, and
    // the work itself has already been told nobody wants it.
    if (_isGone(id)) return;
    _setState(
      id,
      failure != null ? ResearchTaskState.failed : ResearchTaskState.done,
      failure: failure,
    );
  }

  void _setState(int id, ResearchTaskState state, {ResearchFailure? failure}) {
    final index = _indexOf(id);
    if (index < 0) return;
    _queued[index] = _queued[index].withTask(
      _queued[index].task.copyWith(state: state, failure: failure),
    );
    notifyListeners();
  }
}

/// A queued question and the work that answers it.
class _Queued {
  _Queued({required this.task, required this.work, Completer<void>? abandoned})
    : abandoned = abandoned ?? Completer<void>();

  final ResearchTask task;
  final ResearchWork work;

  /// Completed when the row is taken away, which is what lets the queue stop
  /// waiting on work it no longer wants.
  final Completer<void> abandoned;

  _Queued withTask(ResearchTask task) =>
      _Queued(task: task, work: work, abandoned: abandoned);
}
