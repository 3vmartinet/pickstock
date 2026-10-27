import 'package:equatable/equatable.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// How the whole framework is filed, and the prefix of each question's note.
const String frameworkNoteKind = 'framework';

/// The seven questions a company has to clear before it earns a place on a
/// watchlist, in the order they are asked.
///
/// The order is the point of the framework: the cheapest question to settle
/// comes first, and a company that fails it is not worth the other six. Growth
/// is a glance at the filings; the moat and management take reading; timing
/// only matters for a company that has passed everything else.
enum FrameworkQuestion {
  growth(icon: LucideIcons.trendingUp),
  moat(icon: LucideIcons.castle),
  management(icon: LucideIcons.userRoundCheck),
  margins(icon: LucideIcons.percent),
  cash(icon: LucideIcons.wallet),
  risk(icon: LucideIcons.triangleAlert),
  timing(icon: LucideIcons.clock);

  const FrameworkQuestion({required this.icon});

  final IconData icon;

  /// One-based, as the framework numbers them.
  int get number => index + 1;

  /// How this question's answer is filed, under the framework's own kind.
  String get noteKind => '$frameworkNoteKind.$name';

  /// The question as it is asked.
  String getTitle(AppLocalizations strings) => switch (this) {
    FrameworkQuestion.growth => strings.frameworkGrowthTitle,
    FrameworkQuestion.moat => strings.frameworkMoatTitle,
    FrameworkQuestion.management => strings.frameworkManagementTitle,
    FrameworkQuestion.margins => strings.frameworkMarginsTitle,
    FrameworkQuestion.cash => strings.frameworkCashTitle,
    FrameworkQuestion.risk => strings.frameworkRiskTitle,
    FrameworkQuestion.timing => strings.frameworkTimingTitle,
  };

  /// One word for the scorecard, where seven full questions have no room.
  String getLabel(AppLocalizations strings) => switch (this) {
    FrameworkQuestion.growth => strings.frameworkGrowthLabel,
    FrameworkQuestion.moat => strings.frameworkMoatLabel,
    FrameworkQuestion.management => strings.frameworkManagementLabel,
    FrameworkQuestion.margins => strings.frameworkMarginsLabel,
    FrameworkQuestion.cash => strings.frameworkCashLabel,
    FrameworkQuestion.risk => strings.frameworkRiskLabel,
    FrameworkQuestion.timing => strings.frameworkTimingLabel,
  };

  /// What a reader would look at to answer it themselves. Shown before the
  /// model has been asked, so the card says what it will be judged on.
  String getLookFor(AppLocalizations strings) => switch (this) {
    FrameworkQuestion.growth => strings.frameworkGrowthLookFor,
    FrameworkQuestion.moat => strings.frameworkMoatLookFor,
    FrameworkQuestion.management => strings.frameworkManagementLookFor,
    FrameworkQuestion.margins => strings.frameworkMarginsLookFor,
    FrameworkQuestion.cash => strings.frameworkCashLookFor,
    FrameworkQuestion.risk => strings.frameworkRiskLookFor,
    FrameworkQuestion.timing => strings.frameworkTimingLookFor,
  };

  /// The question whose note is filed under [kind], if it is one of these.
  static FrameworkQuestion? fromNoteKind(String kind) {
    for (final question in values) {
      if (question.noteKind == kind) return question;
    }
    return null;
  }
}

/// What a question came back as.
///
/// Three states rather than the framework's two: a model that cannot find
/// management's record should say so rather than be forced into a "no" that
/// reads exactly like a finding. It still keeps a company off the watchlist,
/// which only an unbroken run of yeses earns.
enum FrameworkVerdict {
  yes(icon: LucideIcons.circleCheck),
  no(icon: LucideIcons.circleX),
  unclear(icon: LucideIcons.circleHelp);

  const FrameworkVerdict({required this.icon});

  final IconData icon;

  /// Tolerant: anything that is not plainly a yes or a no is unclear, which is
  /// the honest reading of a reply the model did not shape as asked.
  static FrameworkVerdict parse(String? raw) =>
      switch (raw?.trim().toLowerCase()) {
        'yes' => FrameworkVerdict.yes,
        'no' => FrameworkVerdict.no,
        _ => FrameworkVerdict.unclear,
      };

  /// `true` for a pass, `false` for a fail, `null` for neither — the shape the
  /// theme's outcome colours take.
  bool? get isGood => switch (this) {
    FrameworkVerdict.yes => true,
    FrameworkVerdict.no => false,
    FrameworkVerdict.unclear => null,
  };

  String getLabel(AppLocalizations strings) => switch (this) {
    FrameworkVerdict.yes => strings.frameworkVerdictYes,
    FrameworkVerdict.no => strings.frameworkVerdictNo,
    FrameworkVerdict.unclear => strings.frameworkVerdictUnclear,
  };
}

/// One piece of evidence, and where it was read.
class FrameworkPoint extends Equatable {
  const FrameworkPoint({
    required this.text,
    this.url,
    this.isFromFilings = false,
  });

  final String text;

  /// The page it came from, or `null` where it came from no page. Checked
  /// against the pages the search actually returned before it gets here.
  final String? url;

  /// Whether a point with no page quotes a figure from the filings. Neither a
  /// page nor this is the model's own reading, and is shown as such.
  final bool isFromFilings;

  Map<String, Object?> toJson() => {
    'text': text,
    'url': ?url,
    if (isFromFilings) 'filings': true,
  };

  @override
  List<Object?> get props => [text, url, isFromFilings];
}

/// One question, answered.
///
/// Carries no sources of its own: those are the pages the model read, kept by
/// whoever asked, exactly as an insight's are.
class FrameworkAnswer extends Equatable {
  const FrameworkAnswer({
    required this.verdict,
    required this.headline,
    required this.explanation,
    this.points = const [],
  });

  final FrameworkVerdict verdict;

  /// The answer in a line, which is what the card leads with.
  final String headline;

  /// Why, in two or three sentences.
  final String explanation;

  final List<FrameworkPoint> points;

  /// The shape it is filed in. A note's body is prose for an insight and this
  /// for a framework answer; the kind says which.
  Map<String, Object?> toJson() => {
    'verdict': verdict.name,
    'headline': headline,
    'explanation': explanation,
    'points': [for (final point in points) point.toJson()],
  };

  /// Reads back what [toJson] wrote, or `null` for anything else — a note
  /// that cannot be read is a note that was never taken.
  static FrameworkAnswer? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final headline = json['headline'];
    if (headline is! String || headline.isEmpty) return null;
    final points = json['points'];
    return FrameworkAnswer(
      verdict: FrameworkVerdict.parse(json['verdict'] as String?),
      headline: headline,
      explanation: json['explanation'] as String? ?? '',
      points: [
        if (points is List)
          for (final point in points)
            if (point case {'text': final String text})
              FrameworkPoint(
                text: text,
                url: point['url'] as String?,
                isFromFilings: point['filings'] == true,
              ),
      ],
    );
  }

  @override
  List<Object?> get props => [verdict, headline, explanation, points];
}

/// Where a company stands once its answers are in.
///
/// The framework's rule, applied literally: a single no ends it, and only
/// seven yeses put the company on a watchlist. Anything short of both is not
/// a verdict yet.
enum FrameworkOutcome {
  /// Nothing has been answered.
  notStarted,

  /// Some answers are in and none of them is a no, but not all are yeses.
  incomplete,

  /// At least one no.
  moveOn,

  /// Seven yeses.
  watchlist;

  /// Applies the rule to whatever has been answered so far.
  static FrameworkOutcome from(Iterable<FrameworkVerdict> verdicts) {
    final answered = verdicts.toList();
    if (answered.isEmpty) return FrameworkOutcome.notStarted;
    if (answered.contains(FrameworkVerdict.no)) return FrameworkOutcome.moveOn;
    final allYes =
        answered.length == FrameworkQuestion.values.length &&
        answered.every((verdict) => verdict == FrameworkVerdict.yes);
    return allYes ? FrameworkOutcome.watchlist : FrameworkOutcome.incomplete;
  }
}
