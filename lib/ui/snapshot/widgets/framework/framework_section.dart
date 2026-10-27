import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_question_card.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_scorecard.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// How long the scroll to a question's card takes: long enough to see the
/// page move, so the reader knows they are further down the same tab.
const Duration _jumpDuration = Duration(milliseconds: 360);

/// The framework tab: the scorecard, then the seven questions in order.
///
/// One column rather than a grid of seven: each answer is a paragraph with its
/// evidence beside it, and a grid would cut them all to the height of the
/// shortest or leave holes beside the longest.
class FrameworkSection extends StatefulWidget {
  const FrameworkSection({super.key});

  @override
  State<FrameworkSection> createState() => _FrameworkSectionState();
}

class _FrameworkSectionState extends State<FrameworkSection> {
  final Map<FrameworkQuestion, GlobalKey> _cardKeys = {
    for (final question in FrameworkQuestion.values) question: GlobalKey(),
  };

  void _jumpTo(FrameworkQuestion question) {
    final target = _cardKeys[question]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: _jumpDuration,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: ThemeRepo.spaceLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ThemeRepo.spaceMedium,
        children: [
          FrameworkScorecard(onJump: _jumpTo),
          for (final question in FrameworkQuestion.values)
            FrameworkQuestionCard(key: _cardKeys[question], question: question),
          // Said once for all seven rather than under each: the cards read
          // exactly like the app's own text and did not come from the
          // filings, apart from the panel beside each one, which did.
          Text(context.strings.insightCaveat).muted().xSmall().italic(),
        ],
      ),
    );
  }
}
