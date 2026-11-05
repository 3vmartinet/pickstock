import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_question_card.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The carousel view for the seven questions.
///
/// Displays the active question card. The scorecard on top serves as the
/// selector and displays the focused question in its selected state.
class FrameworkCarouselView extends StatelessWidget {
  const FrameworkCarouselView({
    super.key,
    required this.question,
    required this.onQuestionChanged,
  });

  final FrameworkQuestion question;
  final ValueChanged<FrameworkQuestion> onQuestionChanged;

  void _previous() {
    final prevIndex = (question.index - 1).clamp(
      0,
      FrameworkQuestion.values.length - 1,
    );
    onQuestionChanged(FrameworkQuestion.values[prevIndex]);
  }

  void _next() {
    final nextIndex = (question.index + 1).clamp(
      0,
      FrameworkQuestion.values.length - 1,
    );
    onQuestionChanged(FrameworkQuestion.values[nextIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final isFirst = question.index == 0;
    final isLast = question.index == FrameworkQuestion.values.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: ThemeRepo.spaceMedium,
      children: [
        // The active question card with horizontal gesture detection.
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -120 && !isLast) {
              _next();
            } else if (velocity > 120 && !isFirst) {
              _previous();
            }
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: FrameworkQuestionCard(
              key: ValueKey(question),
              question: question,
            ),
          ),
        ),

        Text(context.strings.insightCaveat).muted().xSmall().italic(),
      ],
    );
  }
}
