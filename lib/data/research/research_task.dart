import 'package:equatable/equatable.dart';
import 'package:pickstock/data/research/company_insight.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';

/// Where a queued question has got to.
///
/// No cancelled state: a cancelled question leaves the list outright, because
/// the list exists to say what is still owed and a row saying "you stopped
/// this" is owed nothing. A failed one stays, because the reason it failed is
/// on the card it was asked from and the row is the way back to it.
enum ResearchTaskState { pending, running, done, failed }

/// One question put to the local model, waiting its turn or answered.
///
/// A model on a laptop answers one question at a time — two at once is two
/// halves of the speed and twice the memory — so these queue rather than run.
/// That makes the wait somebody's problem to track, and the app bar's job list
/// is where the app already tracks work that outlives the screen that started
/// it.
///
/// Carries no copy of its own: what a row says is a matter of locale, and
/// [insight] is enough to say it. What it does carry is where the answer
/// belongs, so a finished row is a way back to it rather than a notification
/// to act on.
class ResearchTask extends Equatable {
  const ResearchTask({
    required this.id,
    required this.cik,
    required this.ticker,
    required this.companyName,
    required this.insight,
    this.state = ResearchTaskState.pending,
  });

  final int id;
  final String cik;
  final String ticker;
  final String companyName;

  /// The question asked, or `null` for the header's reading-around, which is
  /// not one of the three and sits above the tabs rather than on one.
  final CompanyInsight? insight;

  final ResearchTaskState state;

  /// How the answer is filed, which is also what the report highlights when
  /// the reader arrives to look at it.
  String get kind => insight?.name ?? eventsNoteKind;

  /// Which tab a finished question opens onto.
  ///
  /// Each of the three exists because of something its own tab cannot settle,
  /// so the answer is only worth reading beside the arithmetic it qualifies.
  ReportTab get tab => switch (insight) {
    null || CompanyInsight.business => ReportTab.overview,
    CompanyInsight.inputs => ReportTab.valuation,
    CompanyInsight.expectations => ReportTab.expectations,
  };

  bool get isPending => state == ResearchTaskState.pending;

  bool get isRunning => state == ResearchTaskState.running;

  /// Whether the model still owes an answer, which is what makes a row
  /// cancellable rather than openable.
  bool get isActive => isPending || isRunning;

  ResearchTask copyWith({ResearchTaskState? state}) => ResearchTask(
    id: id,
    cik: cik,
    ticker: ticker,
    companyName: companyName,
    insight: insight,
    state: state ?? this.state,
  );

  @override
  List<Object?> get props => [id, cik, ticker, companyName, insight, state];
}
