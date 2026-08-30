import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/sec/bulk_ingest_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/ingest_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Percentages are shown whole; a 1.4 GB download does not need decimals.
const int _percentDigits = 0;

/// Starts the bulk download, and reports how far along it is.
class IngestButton extends StatelessWidget {
  const IngestButton({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<IngestViewModel>();

    return Tooltip(
      tooltip: TooltipContainer(child: Text(context.strings.ingestSize)).call,
      child: GhostButton(
        size: ButtonSize.small,
        onPressed: viewModel.isRunning ? null : viewModel.start,
        leading: viewModel.isRunning
            ? const CircularProgressIndicator(size: ThemeRepo.spaceMedium)
            : const Icon(LucideIcons.download),
        child: Text(_label(context, viewModel)),
      ),
    );
  }

  String _label(BuildContext context, IngestViewModel viewModel) {
    if (viewModel.hasFailed) return context.strings.ingestFailed;
    return switch (viewModel.progress) {
      IngestDownloading(:final fraction) => context.strings.ingestDownloading(
        fraction == null
            ? ''
            : '${(fraction * 100).toStringAsFixed(_percentDigits)}%',
      ),
      IngestParsing(:final companiesRead) => context.strings.ingestParsing(
        companiesRead,
      ),
      IngestDone(:final companyCount) => context.strings.ingestDone(
        companyCount,
      ),
      null => context.strings.ingestStart,
    };
  }
}
