import 'package:equatable/equatable.dart';
import 'package:pickstock/data/research/filings_check.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/valuation/valuation.dart';

/// Where one company stands on the seven questions, as the tiles and
/// the report's tab show it.
class FrameworkScore extends Equatable {
  const FrameworkScore({required this.verdicts});

  /// The score of [answers] against the filings and the price as they are
  /// now: every question settled by [verdictOf], which is what the report
  /// shows.
  ///
  /// The report and the tiles both build their score here, so a company's
  /// tile counts the verdicts its report shows rather than the ones filed
  /// on the day the model was asked — a new price moves timing, and a new
  /// year moves growth, margins, cash or risk, in both at once.
  factory FrameworkScore.settle(
    Map<FrameworkQuestion, FrameworkAnswer> answers, {
    FinancialSnapshot? snapshot,
    Valuation? valuation,
  }) => FrameworkScore(
    verdicts: {
      for (final question in FrameworkQuestion.values)
        question: ?verdictOf(
          question,
          answers[question],
          snapshot: snapshot,
          valuation: valuation,
        ),
    },
  );

  /// The verdict [question] stands at: the filings' where they settle it
  /// now, the model's own answer otherwise, or `null` where neither has one.
  ///
  /// The model's own rather than the one filed: a note filed while the
  /// filings settled the question carries their verdict from that day, and
  /// once a new filing leaves the question to the reading again, the reading
  /// is what counts. Without [snapshot] there is nothing to read the filings
  /// from, and the verdict filed is the last reading of them there is.
  static FrameworkVerdict? verdictOf(
    FrameworkQuestion question,
    FrameworkAnswer? answer, {
    FinancialSnapshot? snapshot,
    Valuation? valuation,
  }) {
    if (snapshot == null) return answer?.verdict;
    final reading = FilingsCheck.of(question, snapshot, valuation: valuation);
    return reading?.verdict ?? answer?.ownVerdict;
  }

  /// The answers on file, by question. Only the ones answered.
  final Map<FrameworkQuestion, FrameworkVerdict> verdicts;

  /// How many questions came back yes, which is what the gauge reads.
  int get satisfied => verdicts.values
      .where((verdict) => verdict == FrameworkVerdict.yes)
      .length;

  int get answered => verdicts.length;

  FrameworkOutcome get outcome => FrameworkOutcome.from(verdicts.values);

  @override
  List<Object?> get props => [verdicts];
}
