import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/institutional_shareholding.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();
ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// An alert shown when active Schedule 13D filings are detected in SEC EDGAR.
class ActivismAlert extends StatelessWidget {
  const ActivismAlert({super.key, required this.holdings});

  final InstitutionalShareholding holdings;

  @override
  Widget build(BuildContext context) {
    if (!holdings.hasActivistStakes) {
      return const SizedBox.shrink();
    }

    final filer = holdings.activistStakes.first;
    final cautionColor = _themeRepo.caution(context.theme);

    return Alert(
      leading: Icon(LucideIcons.megaphone, color: cautionColor).iconSmall(),
      title: Row(
        spacing: ThemeRepo.spaceSmall,
        children: [
          Text('Activist Presence Detected (${filer.formType})')
              .semiBold()
              .small(),
          OutlineBadge(
            child: Text('${_formatRepo.percent(filer.stakePercent)} Stake'),
          ),
        ],
      ),
      content: Text(
        '${filer.name} disclosed a beneficial ownership stake on '
        '${_formatRepo.shortDate(filer.filingDate)}. '
        '${filer.intentSummary}',
      ).muted().xSmall(),
    );
  }
}
