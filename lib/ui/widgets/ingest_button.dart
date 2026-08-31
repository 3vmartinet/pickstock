import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/ui/ingest_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Offers a refresh, but only once SEC has actually rebuilt the archive.
///
/// The archive changes every few days at most, so a button that is always
/// there invites a pointless 1.4 GB download; this one appears when there is
/// something new to fetch and says when it was published.
class IngestButton extends StatelessWidget {
  const IngestButton({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<IngestViewModel>();
    if (!viewModel.isUpdateAvailable) return const SizedBox.shrink();

    final publishedOn = viewModel.availableArchiveDate;

    return Tooltip(
      tooltip: TooltipContainer(
        child: Text(
          publishedOn == null
              ? context.strings.gateRefresh
              : context.strings.updateAvailableOn(publishedOn),
        ),
      ).call,
      child: PrimaryButton(
        size: ButtonSize.small,
        onPressed: viewModel.start,
        leading: const Icon(LucideIcons.refreshCw),
        child: Text(context.strings.updateAvailable),
      ),
    );
  }
}
