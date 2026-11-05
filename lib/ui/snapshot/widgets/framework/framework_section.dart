import 'package:pickstock/data/research/framework_layout.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_carousel_view.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_question_card.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_scorecard.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_vertical_scorecard.dart';
import 'package:pickstock/ui/snapshot/widgets/snapshot_report.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// How long the scroll to a question's card takes: long enough to see the
/// page move, so the reader knows they are further down the same tab.
const Duration _jumpDuration = Duration(milliseconds: 360);

/// Breakpoint below which the vertical pane stacks rather than sitting side by side.
const double _verticalPaneMinWidth = 840;

/// The framework tab: displays the scorecard and the seven questions in one of
/// three layout styles chosen by the user:
/// 1. List: Everything stacked in a single vertical list.
/// 2. Carousel: Scorecard on top, question cards in a horizontal pager.
/// 3. Vertical pane: Scorecard vertically on the left with answers list on the right.
class FrameworkSection extends StatefulWidget {
  const FrameworkSection({super.key});

  @override
  State<FrameworkSection> createState() => _FrameworkSectionState();
}

class _FrameworkSectionState extends State<FrameworkSection> {
  final Map<FrameworkQuestion, GlobalKey> _cardKeys = {
    for (final question in FrameworkQuestion.values) question: GlobalKey(),
  };

  final ScrollController _listScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _listScrollController.addListener(_updateVisibleQuestion);
    _verticalScrollController.addListener(_updateVisibleQuestion);
  }

  @override
  void dispose() {
    _listScrollController.removeListener(_updateVisibleQuestion);
    _listScrollController.dispose();
    _verticalScrollController.removeListener(_updateVisibleQuestion);
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _updateVisibleQuestion() {
    if (!mounted) return;
    final viewModel = context.read<SnapshotViewModel>();
    final layout = viewModel.frameworkLayout;
    final shouldTrack =
        (layout == FrameworkLayout.list && viewModel.isFrameworkListSticky) ||
        (layout == FrameworkLayout.verticalPanel &&
         !viewModel.isFrameworkVerticalCollapsed);
    if (!shouldTrack) return;

    FrameworkQuestion? best;
    double bestDistance = double.infinity;

    for (final entry in _cardKeys.entries) {
      final renderObj = entry.value.currentContext?.findRenderObject();
      if (renderObj is! RenderBox || !renderObj.attached) continue;
      final topInViewport = renderObj.localToGlobal(Offset.zero).dy;
      final distance = topInViewport.abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = entry.key;
      }
    }

    if (best != null && best != viewModel.focusedFrameworkQuestion) {
      viewModel.selectFocusedFrameworkQuestion(best);
    }
  }

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
    final viewModel = context.watch<SnapshotViewModel>();
    final layout = viewModel.frameworkLayout;

    return Padding(
      padding: const EdgeInsets.only(top: ThemeRepo.spaceLarge),
      child: switch (layout) {
        FrameworkLayout.list => _buildListLayout(context),
        FrameworkLayout.carousel => _buildCarouselLayout(context, viewModel),
        FrameworkLayout.verticalPanel =>
          _buildVerticalPaneLayout(context, viewModel),
      },
    );
  }

  Widget _buildListLayout(BuildContext context) {
    final viewModel = context.watch<SnapshotViewModel>();
    final isSticky = viewModel.isFrameworkListSticky;

    if (!isSticky) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ThemeRepo.spaceMedium,
        children: [
          FrameworkScorecard(onJump: _jumpTo),
          for (final question in FrameworkQuestion.values)
            FrameworkQuestionCard(key: _cardKeys[question], question: question),
          Text(context.strings.insightCaveat).muted().xSmall().italic(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FrameworkScorecard(
          onJump: _jumpTo,
          activeQuestion: viewModel.focusedFrameworkQuestion,
        ),
        const SizedBox(height: ThemeRepo.spaceMedium),
        Expanded(
          child: SingleChildScrollView(
            controller: _listScrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: ThemeRepo.spaceMedium,
              children: [
                for (final question in FrameworkQuestion.values)
                  FrameworkQuestionCard(key: _cardKeys[question], question: question),
                Text(context.strings.insightCaveat).muted().xSmall().italic(),
                const ReportFootnotes(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselLayout(
    BuildContext context,
    SnapshotViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: ThemeRepo.spaceMedium,
      children: [
        FrameworkScorecard(
          onJump: (q) => viewModel.selectFocusedFrameworkQuestion(q),
          activeQuestion: viewModel.focusedFrameworkQuestion,
        ),
        FrameworkCarouselView(
          question: viewModel.focusedFrameworkQuestion,
          onQuestionChanged: (q) => viewModel.selectFocusedFrameworkQuestion(q),
        ),
      ],
    );
  }

  Widget _buildVerticalPaneLayout(
    BuildContext context,
    SnapshotViewModel viewModel,
  ) {
    final isCollapsed = viewModel.isFrameworkVerticalCollapsed;
    final focused = viewModel.focusedFrameworkQuestion;

    return LayoutBuilder(
      builder: (context, constraints) {
        final scorecard = SizedBox(
          width: 310,
          child: SingleChildScrollView(
            child: FrameworkVerticalScorecard(
              onJump: (q) {
                viewModel.selectFocusedFrameworkQuestion(q);
                if (!isCollapsed) {
                  _jumpTo(q);
                }
              },
              activeQuestion: focused,
            ),
          ),
        );

        final answersContent = isCollapsed
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.03),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: FrameworkQuestionCard(
                  key: ValueKey(focused),
                  question: focused,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: ThemeRepo.spaceMedium,
                children: [
                  for (final question in FrameworkQuestion.values)
                    FrameworkQuestionCard(
                      key: _cardKeys[question],
                      question: question,
                    ),
                ],
              );

        if (constraints.maxWidth >= _verticalPaneMinWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: ThemeRepo.spaceMedium,
            children: [
              scorecard,
              Expanded(
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: ThemeRepo.spaceMedium,
                    children: [
                      answersContent,
                      Text(context.strings.insightCaveat)
                          .muted()
                          .xSmall()
                          .italic(),
                      const ReportFootnotes(),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // Stacked vertically when the window is narrow.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: ThemeRepo.spaceMedium,
          children: [
            FrameworkVerticalScorecard(
              onJump: (q) {
                viewModel.selectFocusedFrameworkQuestion(q);
                if (!isCollapsed) {
                  _jumpTo(q);
                }
              },
              activeQuestion: focused,
            ),
            answersContent,
            Text(context.strings.insightCaveat).muted().xSmall().italic(),
          ],
        );
      },
    );
  }
}
