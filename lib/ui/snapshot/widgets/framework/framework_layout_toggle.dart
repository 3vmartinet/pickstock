import 'package:pickstock/data/research/framework_layout.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The segmented control for choosing how the seven questions are displayed:
/// as a single vertical list, a horizontal carousel pager, or a two-column
/// vertical pane.
class FrameworkLayoutToggle extends StatelessWidget {
  const FrameworkLayoutToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SnapshotViewModel>();
    final current = viewModel.frameworkLayout;
    final strings = context.strings;

    return ButtonGroup(
      children: [
        for (final layout in FrameworkLayout.values)
          Tooltip(
            tooltip: HintTooltip(
              '${layout.getLabel(strings)}: ${layout.getHint(strings)}',
            ).call,
            child: layout == current
                ? IconButton.secondary(
                    size: ButtonSize.small,
                    density: ButtonDensity.icon,
                    icon: Icon(layout.icon).iconSmall(),
                    onPressed: () {},
                  )
                : IconButton.ghost(
                    size: ButtonSize.small,
                    density: ButtonDensity.icon,
                    icon: Icon(layout.icon).iconSmall(),
                    onPressed: () => viewModel.selectFrameworkLayout(layout),
                  ),
          ),
      ],
    );
  }
}

