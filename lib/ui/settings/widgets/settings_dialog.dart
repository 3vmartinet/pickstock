import 'package:get_it/get_it.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/ingest_view_model.dart';
import 'package:pickstock/ui/settings/settings_view_model.dart';
import 'package:pickstock/ui/widgets/app_dialog.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();

/// Opens the settings, from the app menu's Settings… item or ⌘,.
///
/// A dialog because Flutter draws this app in one window: Apple's guidance is
/// a separate settings window, and a dialog over the app is the nearest thing
/// to one — it leaves what the reader was doing in place behind it rather than
/// navigating away from it, which a screen of its own would.
///
/// Laid out as Apple asks of a settings window with a single pane: titled
/// "PickStock Settings", every change applied the moment it is made, and so
/// no OK or Apply — only the way out.
Future<void> showSettings(BuildContext context) =>
    showAppDialog<void>(context, builder: (_) => const SettingsDialog());

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: ThemeRepo.settingsDialogWidth,
      ),
      child: Card(
        padding: const EdgeInsets.all(ThemeRepo.spaceLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: ThemeRepo.spaceMedium,
          children: const [_Header(), Divider(), _SecDataSection()],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(context.strings.settingsTitle).large().semiBold()),
        Tooltip(
          tooltip: HintTooltip(context.strings.settingsClose).call,
          child: GhostButton(
            density: ButtonDensity.icon,
            onPressed: () => closeAppDialog<void>(context),
            child: const Icon(LucideIcons.x).iconSmall(),
          ),
        ),
      ],
    );
  }
}

/// A group of related settings: what they are about, then one row each.
///
/// shadcn's field set — a legend, a line saying what the group is for, and
/// the rows — so the next setting has a place to go that is not "the bottom
/// of the dialog".
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: ThemeRepo.spaceSmall,
      children: [
        Text(title).semiBold(),
        Text(description).muted().small(),
        const SizedBox(height: ThemeRepo.spaceXSmall),
        ...children,
      ],
    );
  }
}

/// One on/off setting, the way shadcn draws one in a settings form: a
/// bordered row with what it does on the left and the switch on the right, so
/// a column of them lines their switches up along one edge.
///
/// The whole row is the target, not just the switch: the label is the larger
/// thing to aim at, and a row that ignored a press on its own words would feel
/// broken.
class SettingSwitchRow extends StatelessWidget {
  const SettingSwitchRow({
    super.key,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Clickable(
      mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
      onPressed: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(ThemeRepo.spaceMedium),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.border),
          borderRadius: theme.borderRadiusLg,
        ),
        child: Row(
          spacing: ThemeRepo.spaceMedium,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: ThemeRepo.spaceXSmall,
                children: [
                  Text(label).small().medium(),
                  Text(description).muted().xSmall(),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _SecDataSection extends StatelessWidget {
  const _SecDataSection();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final autoDownload = context.select<SettingsViewModel, bool>(
      (viewModel) => viewModel.autoDownloadUpdates,
    );

    return _Section(
      title: strings.settingsSecDataTitle,
      description: strings.settingsSecDataDescription,
      children: [
        SettingSwitchRow(
          key: autoDownloadSwitchKey,
          label: strings.settingsAutoDownloadLabel,
          description: strings.settingsAutoDownloadDescription,
          value: autoDownload,
          onChanged: (value) async {
            await context.read<SettingsViewModel>().setAutoDownloadUpdates(
              value,
            );
            // Turned on with an update already waiting: it means now, not at
            // the next launch.
            if (value && context.mounted) {
              context.read<IngestViewModel>().downloadUpdateIfWanted();
            }
          },
        ),
        const _UpdateStatus(),
      ],
    );
  }
}

/// Where the data stands, under the switch that decides how it is kept
/// current — so turning it on visibly does something when there is something
/// to do.
class _UpdateStatus extends StatelessWidget {
  const _UpdateStatus();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ingest = context.watch<IngestViewModel>();
    final loaded = ingest.loadedArchiveDate;
    final available = ingest.availableArchiveDate;
    final percent = ingest.updatePercent;

    final status = switch (ingest.updatePhase) {
      UpdatePhase.none when loaded != null => strings.settingsStatusCurrent(
        _formatRepo.shortDate(loaded),
      ),
      UpdatePhase.none => null,
      UpdatePhase.offered => strings.settingsStatusOffered(
        available == null ? '' : _formatRepo.shortDate(available),
      ),
      UpdatePhase.downloading when percent != null =>
        strings.settingsStatusDownloadingPercent(percent),
      UpdatePhase.downloading => strings.settingsStatusDownloading,
      UpdatePhase.cancelling => strings.settingsStatusCancelling,
      UpdatePhase.staged => strings.settingsStatusStaged,
      UpdatePhase.loading when percent != null =>
        strings.settingsStatusLoadingPercent(percent),
      UpdatePhase.loading => strings.settingsStatusLoading,
      UpdatePhase.failed => strings.settingsStatusFailed,
    };
    if (status == null) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceXSmall,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(LucideIcons.info),
        ).iconXSmall().iconMutedForeground(),
        Expanded(child: Text(status).muted().xSmall()),
      ],
    );
  }
}

/// Finds the auto-download row in a test.
const Key autoDownloadSwitchKey = ValueKey('autoDownloadSwitch');
