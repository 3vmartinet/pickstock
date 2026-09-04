import 'package:flutter_animate/flutter_animate.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/widgets/app_dialog.dart';
import 'package:pickstock/ui/ingest_view_model.dart';
import 'package:provider/provider.dart';
import 'package:pickstock/ui/widgets/edge_progress.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// The app bar's one word on the state of the data: which day it is from, and
/// what can be done about it.
///
/// The archive changes every few days at most, so a refresh button that is
/// always there invites a pointless 1.4 GB download; with nothing on offer
/// this is a quiet line of text saying when SEC published what is loaded.
/// Once there is something new it becomes a button, dotted to catch the eye,
/// and pressing it starts the downloads behind the app rather than in front
/// of it — several minutes is far too long to be locked out for work that
/// touches nothing. It then becomes the progress indicator, and finally the
/// go-ahead for the database step, which does have to block.
class IngestButton extends StatelessWidget {
  const IngestButton({super.key});

  @override
  Widget build(BuildContext context) {
    final phase = context.select<IngestViewModel, UpdatePhase>(
      (viewModel) => viewModel.updatePhase,
    );

    return switch (phase) {
      UpdatePhase.none => const _DataDate(),
      UpdatePhase.offered => const _Offer(),
      UpdatePhase.downloading => const _Downloading(),
      UpdatePhase.staged => const _Staged(),
      UpdatePhase.failed => const _Failed(),
    };
  }
}

/// What stands where the button goes when there is nothing to offer: the day
/// the figures come from.
///
/// Nothing to do is worth saying out loud — an app bar that is simply empty
/// leaves "is my data current?" unanswered, and the answer is one line of
/// text. Deliberately quiet: it is a fact to glance at, not an action.
class _DataDate extends StatelessWidget {
  const _DataDate();

  @override
  Widget build(BuildContext context) {
    final loadedOn = context.select<IngestViewModel, DateTime?>(
      (viewModel) => viewModel.loadedArchiveDate,
    );
    // An ingest from before the date was recorded has nothing to show, and a
    // label with a blank in it is worse than no label.
    //
    // Dropped on a narrow window too, as the app bar's subtitle is: there the
    // row has no room to spare, and this is the least of what is in it.
    if (loadedOn == null || context.isCompact) return const SizedBox.shrink();

    return Tooltip(
      tooltip: HintTooltip(context.strings.dataAsOfHint(loadedOn)).call,
      child: Container(
        padding: ThemeRepo.dataStampPadding,
        // A box of its own, so two lines of small type read as one stamp
        // rather than as text left loose in the app bar beside the buttons.
        decoration: BoxDecoration(
          color: context.theme.colorScheme.muted,
          borderRadius: context.theme.borderRadiusMd,
        ),
        // Two lines: "SEC data" heads the date rather than reading as part of
        // the same phrase with it, and stacked they take a fraction of the app
        // bar's width that one line was claiming.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StampLine(context.strings.dataAsOfLabel),
            _StampLine(context.strings.dataAsOfDate(loadedOn)),
          ],
        ),
      ),
    );
  }
}

/// One line of the data stamp, set tight so the pair reads as a block.
class _StampLine extends StatelessWidget {
  const _StampLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: ThemeRepo.dataStampFontSize,
      height: ThemeRepo.dataStampLineHeight,
    ),
  ).muted().singleLine();
}

/// A newer archive is out and nothing has been fetched yet.
class _Offer extends StatelessWidget {
  const _Offer();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<IngestViewModel>();
    final publishedOn = viewModel.availableArchiveDate;

    return _CornerBadge(
      // Red for something new to fetch.
      colour: context.theme.colorScheme.destructive,
      child: _ActionButton(
        hint: publishedOn == null
            ? context.strings.gateRefresh
            : context.strings.updateAvailableOn(publishedOn),
        leading: const Icon(LucideIcons.refreshCw),
        label: context.strings.updateAvailable,
        onPressed: viewModel.downloadUpdate,
      ),
    );
  }
}

/// Marks its child as needing attention.
///
/// The button already says what it is for, so the dot is not carrying the
/// message — it is there to catch the eye of someone who was not reading the
/// app bar. Red for an update that has just been published, orange for one
/// downloaded and waiting to be let in: two different things to do, and at a
/// glance the colour is the faster of the two to read.
class _CornerBadge extends StatelessWidget {
  const _CornerBadge({required this.colour, required this.child});

  final Color colour;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      // The dot sits outside the button's bounds, so it must not be trimmed
      // back to them.
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: ThemeRepo.updateBadgeOffset,
          left: ThemeRepo.updateBadgeOffset,
          child: Container(
            key: updateBadgeKey,
            width: ThemeRepo.updateBadgeSize,
            height: ThemeRepo.updateBadgeSize,
            decoration: BoxDecoration(shape: BoxShape.circle, color: colour),
          ),
        ),
      ],
    );
  }
}

/// The downloads are running behind the app.
///
/// Turning arrows rather than a spinner: they are the same arrows the offer
/// was pressed with, so the button reads as that press still being carried
/// out rather than as a new thing having appeared.
class _Downloading extends StatelessWidget {
  const _Downloading();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<IngestViewModel>();
    final percent = viewModel.updatePercent;
    final hint = context.strings.updateDownloadingHint;

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: ThemeRepo.spaceXSmall,
      children: [
        EdgeProgress(
          // Null until the archive itself starts coming down, which shows the
          // indeterminate bar: the two short stages before it have no size
          // worth putting a figure on.
          fraction: viewModel.updateFraction,
          // On a filled button, so the bar is drawn in its own foreground.
          colour: context.theme.colorScheme.primaryForeground,
          child: _ActionButton(
            // The figure goes in the tooltip, not the label: a label that
            // changed a hundred times would jitter the app bar, and the bar
            // underneath says as much at a glance.
            hint: percent == null
                ? hint
                : '$hint ${context.strings.updateDownloadedPercent(percent)}',
            leading: const Icon(LucideIcons.refreshCw)
                .animate(onPlay: (controller) => controller.repeat())
                .rotate(duration: ThemeRepo.updateSpinDuration),
            label: context.strings.updateDownloading,
            // Nothing to press: it is already happening, and stopping it is
            // the button beside this one.
            onPressed: null,
          ),
        ),
        const _CancelButton(),
      ],
    );
  }
}

/// Stops the download, as the other half of the button beside it.
///
/// The same fill and size, so the pair reads as one control rather than as an
/// icon that wandered into the app bar.
class _CancelButton extends StatelessWidget {
  const _CancelButton();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      tooltip: HintTooltip(context.strings.updateCancelHint).call,
      child: Button(
        key: updateCancelKey,
        style: const ButtonStyle.primary(
          size: ButtonSize.small,
          density: ButtonDensity.icon,
        ),
        onPressed: context.read<IngestViewModel>().cancelDownload,
        child: const Icon(LucideIcons.x).iconSmall(),
      ),
    );
  }
}

/// Everything is downloaded; the database step is waiting to be allowed.
class _Staged extends StatelessWidget {
  const _Staged();

  @override
  Widget build(BuildContext context) {
    return _CornerBadge(
      // Orange for something waiting on the user rather than newly published.
      colour: _themeRepo.caution(context.theme),
      child: _ActionButton(
        hint: context.strings.updateReadyHint,
        leading: const Icon(LucideIcons.databaseZap),
        label: context.strings.updateReady,
        onPressed: () => _confirmRefresh(context),
      ),
    );
  }
}

/// Asks before shutting the app for several minutes.
///
/// The press is a decision with a cost, and the cost is knowable: the last
/// load was timed, and the archive and the machine are much the same each
/// time, so the dialog can say roughly how long rather than "a while".
Future<void> _confirmRefresh(BuildContext context) async {
  final viewModel = context.read<IngestViewModel>();
  final taken = viewModel.lastLoadDuration;

  final confirmed = await showAppDialog<bool>(
    context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.strings.updateConfirmTitle),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: ThemeRepo.spaceSmall,
        children: [
          Text(context.strings.updateConfirmBody),
          Text(
            taken == null
                ? context.strings.updateConfirmUntimed
                : context.strings.updateConfirmLast(_wholeMinutes(taken)),
          ).muted().small(),
        ],
      ),
      actions: [
        OutlineButton(
          onPressed: () => closeAppDialog(dialogContext, false),
          child: Text(context.strings.updateConfirmCancel),
        ),
        PrimaryButton(
          onPressed: () => closeAppDialog(dialogContext, true),
          child: Text(context.strings.updateConfirmStart),
        ),
      ],
    ),
  );

  if (confirmed ?? false) await viewModel.applyUpdate();
}

/// [taken] in whole minutes, and never none of them: "about 0 minutes" says
/// nothing, and no load has ever been that quick.
int _wholeMinutes(Duration taken) {
  final minutes = (taken.inSeconds / Duration.secondsPerMinute).round();
  return minutes < 1 ? 1 : minutes;
}

/// The background download did not finish. Nothing was written, so this is an
/// offer to try again rather than a problem to recover from.
class _Failed extends StatelessWidget {
  const _Failed();

  @override
  Widget build(BuildContext context) {
    return _ActionButton(
      hint: context.strings.updateFailedHint,
      leading: const Icon(LucideIcons.triangleAlert),
      label: context.strings.updateFailed,
      onPressed: context.read<IngestViewModel>().downloadUpdate,
    );
  }
}

/// The one button every phase wears, so the app bar's shape does not change
/// as a refresh moves through them.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.hint,
    required this.leading,
    required this.label,
    required this.onPressed,
  });

  final String hint;
  final Widget leading;
  final String label;

  /// `null` leaves the button inert, which is what a step already under way
  /// needs.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      tooltip: HintTooltip(hint).call,
      child: PrimaryButton(
        size: ButtonSize.small,
        // Kept solid even with nothing to press. Left to work itself out from
        // `onPressed`, the download's button greys off to a muted outline —
        // which beside the solid cancel button reads as two unrelated
        // controls, one of them broken, rather than as one thing happening.
        enabled: true,
        onPressed: onPressed,
        leading: leading,
        child: Text(label),
      ),
    );
  }
}

/// The dot that marks an update as needing attention.
const Key updateBadgeKey = Key('updateBadge');

/// The button that stops a download in progress.
const Key updateCancelKey = Key('updateCancel');
