import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/app_route.dart';
import 'package:pickstock/ui/app_view_model.dart';
import 'package:pickstock/ui/widgets/ingest_button.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/snapshot/widgets/snapshot_body.dart';
import 'package:pickstock/ui/snapshot/widgets/ticker_search_bar.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

class SnapshotScreen extends StatelessWidget {
  const SnapshotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.isLoading,
    );

    return Scaffold(
      loadingProgressIndeterminate: isLoading,
      headers: const [_SnapshotAppBar(), TickerSearchBar(), Divider()],
      child: const SnapshotBody(),
    );
  }
}

class _SnapshotAppBar extends StatelessWidget {
  const _SnapshotAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: const [_BrandMark()],
      title: Text(context.strings.appTitle),
      subtitle: context.isCompact ? null : Text(context.strings.appSubtitle),
      trailing: const [IngestButton(), _BrowseButton(), _ThemeToggleButton()],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ThemeRepo.spaceSmall),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.primary,
        borderRadius: context.theme.borderRadiusMd,
      ),
      child: const Icon(LucideIcons.chartNoAxesColumn)
          .iconSmall()
          .iconPrimaryForeground(),
    );
  }
}

class _BrowseButton extends StatelessWidget {
  const _BrowseButton();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      tooltip: TooltipContainer(child: Text(context.strings.browseOpen)).call,
      child: GhostButton(
        density: ButtonDensity.icon,
        onPressed: () => Navigator.of(context).pushNamed(AppRoute.browse.path),
        child: const Icon(LucideIcons.list),
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    return Tooltip(
      tooltip: TooltipContainer(child: Text(context.strings.toggleTheme)).call,
      child: GhostButton(
        density: ButtonDensity.icon,
        onPressed: () =>
            context.read<AppViewModel>().toggleTheme(context.theme.brightness),
        child: Icon(isDark ? LucideIcons.sun : LucideIcons.moon),
      ),
    );
  }
}

/// Renders whichever of the four screen states the view model is in.
