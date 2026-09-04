import 'package:flutter_animate/flutter_animate.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/ingest_view_model.dart';
import 'package:provider/provider.dart';
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
      child: Text(context.strings.dataAsOf(loadedOn))
          .muted()
          .xSmall()
          .singleLine(),
    );
  }
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
        _EdgeProgress(
          // Null until the archive itself starts coming down, which shows the
          // indeterminate bar: the two short stages before it have no size
          // worth putting a figure on.
          fraction: viewModel.updateFraction,
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

/// Draws [fraction] along the bottom edge of [child].
///
/// Inside the button's own outline rather than under it: a bar of its own
/// below the row would make the app bar taller as a download started, and the
/// button is the thing the progress belongs to.
class _EdgeProgress extends StatelessWidget {
  const _EdgeProgress({required this.fraction, required this.child});

  /// `null` shows the indeterminate bar, for a stage with no known size.
  final double? fraction;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      // The same radius the button draws itself with, so the bar picks up its
      // corners instead of squaring them off.
      borderRadius: context.theme.borderRadiusMd,
      child: Stack(
        children: [
          child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ComponentTheme<ProgressTheme>(
              // Squared off, because the clip above supplies the only corners
              // the bar should have; and drawn in the button's own foreground,
              // since the default colours are meant for a bar on a page
              // rather than on a filled button.
              data: ProgressTheme(
                minHeight: ThemeRepo.updateProgressHeight,
                borderRadius: BorderRadius.zero,
                color: context.theme.colorScheme.primaryForeground,
                backgroundColor: context.theme.colorScheme.primaryForeground
                    .withValues(alpha: ThemeRepo.updateProgressTrack),
              ),
              child: Progress(progress: fraction),
            ),
          ),
        ],
      ),
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
        onPressed: context.read<IngestViewModel>().applyUpdate,
      ),
    );
  }
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

  /// `null` leaves the button in place but inert, which is what a step already
  /// under way needs.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      tooltip: HintTooltip(hint).call,
      child: PrimaryButton(
        size: ButtonSize.small,
        enabled: onPressed != null,
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
