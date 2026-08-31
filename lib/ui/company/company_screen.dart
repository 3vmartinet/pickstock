import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/snapshot/widgets/snapshot_body.dart';
import 'package:pickstock/ui/widgets/theme_toggle_button.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// One company's report, on its own screen.
///
/// Only reached on windows too narrow to show the report beside the list; on a
/// wide window the same report fills the detail pane instead.
class CompanyScreen extends StatelessWidget {
  const CompanyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.isLoading,
    );

    return Scaffold(
      loadingProgressIndeterminate: isLoading,
      headers: const [_CompanyAppBar(), Divider()],
      child: const SnapshotBody(),
    );
  }
}

class _CompanyAppBar extends StatelessWidget {
  const _CompanyAppBar();

  @override
  Widget build(BuildContext context) {
    final company = context.select<SnapshotViewModel, Company?>(
      (viewModel) => viewModel.snapshot?.company,
    );

    return AppBar(
      padding: EdgeInsets.symmetric(
        horizontal: context.pageGutter,
        vertical: ThemeRepo.appBarVerticalPadding,
      ),
      leading: const [_BackButton()],
      title: Text(company?.name ?? context.strings.appTitle),
      subtitle: company == null ? null : Text(company.ticker),
      trailing: const [ThemeToggleButton()],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      tooltip: TooltipContainer(child: Text(context.strings.backToList)).call,
      child: GhostButton(
        density: ButtonDensity.icon,
        onPressed: Navigator.of(context).pop,
        child: const Icon(LucideIcons.arrowLeft),
      ),
    );
  }
}
