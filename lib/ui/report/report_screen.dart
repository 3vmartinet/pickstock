import 'package:get_it/get_it.dart';
import 'package:pickstock/data/report/valuation_report.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/app_route.dart';
import 'package:pickstock/ui/report/jobs_view_model.dart';
import 'package:pickstock/ui/report/widgets/report_actions.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();
ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// One finished scan: the companies priced below the range their filings
/// support, most upside first.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  ValuationReport? _report;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isLoading) return;
    final id = ModalRoute.of(context)?.settings.arguments;
    if (id is! int) return;
    context.read<JobsViewModel>().load(id).then((loaded) {
      if (!mounted) return;
      setState(() {
        _report = loaded;
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      headers: [
        AppBar(
          padding: EdgeInsets.symmetric(
            horizontal: context.pageGutter,
            vertical: ThemeRepo.appBarVerticalPadding,
          ),
          leading: const [_BackButton()],
          title: Text(report?.name ?? context.strings.jobsTitle),
          subtitle: report == null
              ? null
              : Text(
                  context.strings.reportSubtitle(
                    report.entries.length,
                    report.valuedCount,
                    report.consideredCount,
                  ),
                ),
          trailing: [
            if (report != null)
              ReportActions(
                report: report,
                onDeleted: () => Navigator.of(context).pop(),
              ),
          ],
        ),
        const Divider(),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : report == null
          ? const SizedBox.shrink()
          : _ReportBody(report: report),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      tooltip: HintTooltip(context.strings.backToList).call,
      child: GhostButton(
        density: ButtonDensity.icon,
        onPressed: Navigator.of(context).pop,
        child: const Icon(LucideIcons.arrowLeft),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final ValuationReport report;

  @override
  Widget build(BuildContext context) {
    if (report.entries.isEmpty) return _EmptyReport(report: report);

    final skipped = report.consideredCount - report.valuedCount;

    return ListView.separated(
      padding: context.pagePadding,
      itemCount: report.entries.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: ThemeRepo.spaceSmall),
      itemBuilder: (context, index) {
        if (index == report.entries.length) {
          return skipped <= 0
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: ThemeRepo.spaceMedium),
                  child: Text(context.strings.reportSkippedNote(skipped))
                      .muted()
                      .xSmall(),
                );
        }
        return _EntryRow(entry: report.entries[index], rank: index + 1);
      },
    );
  }
}

/// One company, and how far below its range it is trading.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.rank});

  final ReportEntry entry;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Button(
      style: const ButtonStyle.outline(),
      alignment: AlignmentDirectional.centerStart,
      // Opens the company itself, because the next question after "this looks
      // cheap" is always "why".
      onPressed: () {
        context.read<SnapshotViewModel>().search(entry.ticker);
        Navigator.of(context).pushNamed(AppRoute.company.path);
      },
      child: Row(
        spacing: ThemeRepo.spaceMedium,
        children: [
          SizedBox(
            width: ThemeRepo.reportRankWidth,
            child: Text('$rank').muted().xSmall(),
          ),
          SizedBox(
            width: ThemeRepo.reportTickerWidth,
            child: Text(entry.ticker).mono().small().semiBold().singleLine(),
          ),
          Expanded(child: Text(entry.name).small().singleLine()),
          _Figure(
            label: context.strings.reportColumnPrice,
            value: _formatRepo.price(entry.pricePerShare),
          ),
          _Figure(
            label: context.strings.reportColumnRange,
            value:
                '${_formatRepo.price(entry.fairValueLow)}'
                ' – ${_formatRepo.price(entry.fairValueHigh)}',
          ),
          _Figure(
            label: context.strings.reportColumnUpside,
            value: _formatRepo.signedPercent(entry.upsidePercent),
            colour: _themeRepo.positive(context.theme),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.colour});

  final String label;
  final String value;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ThemeRepo.reportFigureWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: ThemeRepo.spaceXSmall,
        children: [
          Text(label).muted().xSmall().singleLine(),
          Text(value).small().semiBold(color: colour).singleLine(),
        ],
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport({required this.report});

  final ValuationReport report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ThemeRepo.spaceXXLarge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: ThemeRepo.spaceSmall,
        children: [
          const Icon(LucideIcons.searchX).iconXLarge().iconMutedForeground(),
          Text(context.strings.reportEmptyTitle).h4().textCenter(),
          Text(context.strings.reportEmptyBody).muted().textCenter(),
        ],
      ),
    );
  }
}
