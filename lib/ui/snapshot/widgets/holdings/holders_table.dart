import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/institutional_shareholding.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/widgets/section_header.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();
ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// Top institutional holders from Form 13F / 13G filings.
class HoldingsTable extends StatefulWidget {
  const HoldingsTable({super.key, required this.holdings});

  final InstitutionalShareholding holdings;

  @override
  State<HoldingsTable> createState() => _HoldingsTableState();
}

class _HoldingsTableState extends State<HoldingsTable> {
  bool _sortByChange = false;

  @override
  Widget build(BuildContext context) {
    final rawHoldings = widget.holdings.topHolders;
    final sorted = List<InstitutionalHolder>.from(rawHoldings);
    if (_sortByChange) {
      sorted.sort(
        (a, b) => (b.changeSharesQoQ ?? 0).compareTo(a.changeSharesQoQ ?? 0),
      );
    } else {
      sorted.sort((a, b) => b.sharesHeld.compareTo(a.sharesHeld));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: ThemeRepo.spaceSmall,
      children: [
        Row(
          children: [
            Expanded(
              child: SectionHeader(
                icon: LucideIcons.building2,
                title: context.strings.sectionTopHoldings,
              ),
            ),
            OutlineBadge(
              child: Text(
                context.strings.holdingsCycleLabel(
                  widget.holdings.calendarQuarter,
                ),
              ),
            ),
            const SizedBox(width: ThemeRepo.spaceSmall),
            GhostButton(
              density: ButtonDensity.compact,
              onPressed: () => setState(() => _sortByChange = !_sortByChange),
              leading: Icon(
                _sortByChange ? LucideIcons.trendingUp : LucideIcons.arrowDownUp,
              ).iconXSmall(),
              child: Text(_sortByChange ? 'Sort: Flow' : 'Sort: Stake'),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth < ThemeRepo.historyTableMinWidth
              ? _HolderCards(holders: sorted)
              : _WideHoldersTable(holders: sorted),
        ),
      ],
    );
  }
}

class _WideHoldersTable extends StatelessWidget {
  const _WideHoldersTable({required this.holders});

  final List<InstitutionalHolder> holders;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Card(
      padding: EdgeInsets.zero,
      child: Table(
        columnWidths: const {
          0: FlexTableSize(flex: 2.4),
          1: FlexTableSize(flex: 1.0),
          2: FlexTableSize(flex: 1.0),
          3: FlexTableSize(flex: 1.0),
          4: FlexTableSize(flex: 0.9),
          5: FlexTableSize(flex: 0.8),
        },
        rows: [
          TableHeader(
            cells: [
              _headingCell(context, strings.colInstitution, isNumeric: false),
              _headingCell(context, strings.colSharesHeld, isNumeric: true),
              _headingCell(context, strings.colMarketValue, isNumeric: true),
              _headingCell(context, strings.colQoQChange, isNumeric: true),
              _headingCell(context, strings.colPortfolioPercent, isNumeric: true),
              _headingCell(context, strings.colFiling, isNumeric: false),
            ],
          ),
          for (final holder in holders)
            TableRow(
              cells: [
                _institutionCell(context, holder),
                _sharesCell(context, holder),
                _valueCell(context, holder),
                _changeCell(context, holder),
                _portfolioCell(context, holder),
                _filingCell(context, holder),
              ],
            ),
        ],
      ),
    );
  }

  TableCell _headingCell(
    BuildContext context,
    String title, {
    required bool isNumeric,
  }) {
    return TableCell(
      child: Container(
        padding: ThemeRepo.tableCellPadding,
        alignment: isNumeric ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(title).muted().semiBold().xSmall().singleLine(),
      ),
    );
  }

  TableCell _institutionCell(BuildContext context, InstitutionalHolder holder) {
    return TableCell(
      child: Container(
        padding: ThemeRepo.tableCellPadding,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: ThemeRepo.spaceXSmall,
          children: [
            Text(holder.name).semiBold().small(),
            SecondaryBadge(
              child: Text(holder.managerType.getLabel(context.strings)),
            ),
          ],
        ),
      ),
    );
  }

  TableCell _sharesCell(BuildContext context, InstitutionalHolder holder) {
    final count = _formatRepo.compactCount(holder.sharesHeld);
    final pct = _formatRepo.percent(holder.percentOfClass);
    return TableCell(
      child: Container(
        padding: ThemeRepo.tableCellPadding,
        alignment: Alignment.centerRight,
        child: Text('$count ($pct)').small().singleLine(),
      ),
    );
  }

  TableCell _valueCell(BuildContext context, InstitutionalHolder holder) {
    return TableCell(
      child: Container(
        padding: ThemeRepo.tableCellPadding,
        alignment: Alignment.centerRight,
        child: Text(_formatRepo.compactCurrency(holder.marketValue)).small().singleLine(),
      ),
    );
  }

  TableCell _changeCell(BuildContext context, InstitutionalHolder holder) {
    if (holder.isNewPosition) {
      return TableCell(
        child: Container(
          padding: ThemeRepo.tableCellPadding,
          alignment: Alignment.centerRight,
          child: const PrimaryBadge(child: Text('NEW')),
        ),
      );
    }

    final change = holder.changeSharesQoQ;
    if (change == null || change == 0) {
      return TableCell(
        child: Container(
          padding: ThemeRepo.tableCellPadding,
          alignment: Alignment.centerRight,
          child: Text('—').muted().small().singleLine(),
        ),
      );
    }

    final isPositive = change > 0;
    final accent = _themeRepo.forOutcome(context.theme, isGood: isPositive);
    final sign = isPositive ? '+' : '';
    final countText = '$sign${_formatRepo.compactCount(change)}';
    final pctText = holder.changePercentQoQ != null
        ? ' ($sign${_formatRepo.percent(holder.changePercentQoQ!)})'
        : '';

    return TableCell(
      child: Container(
        padding: ThemeRepo.tableCellPadding,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: ThemeRepo.spaceXSmall,
          children: [
            Icon(
              isPositive ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight,
              color: accent,
            ).iconXSmall(),
            Text('$countText$pctText').small(color: accent).singleLine(),
          ],
        ),
      ),
    );
  }

  TableCell _portfolioCell(BuildContext context, InstitutionalHolder holder) {
    final pct = holder.portfolioPercent;
    return TableCell(
      child: Container(
        padding: ThemeRepo.tableCellPadding,
        alignment: Alignment.centerRight,
        child: Text(pct == null ? '—' : _formatRepo.percent(pct)).small().singleLine(),
      ),
    );
  }

  TableCell _filingCell(BuildContext context, InstitutionalHolder holder) {
    return TableCell(
      child: Container(
        padding: ThemeRepo.tableCellPadding,
        alignment: Alignment.centerLeft,
        child: OutlineBadge(child: Text(holder.formType)),
      ),
    );
  }
}

class _HolderCards extends StatelessWidget {
  const _HolderCards({required this.holders});

  final List<InstitutionalHolder> holders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: ThemeRepo.spaceSmall,
      children: [
        for (final holder in holders) _HolderCard(holder: holder),
      ],
    );
  }
}

class _HolderCard extends StatelessWidget {
  const _HolderCard({required this.holder});

  final InstitutionalHolder holder;

  @override
  Widget build(BuildContext context) {
    final count = _formatRepo.compactCount(holder.sharesHeld);
    final pct = _formatRepo.percent(holder.percentOfClass);
    final value = _formatRepo.compactCurrency(holder.marketValue);
    final change = holder.changeSharesQoQ;
    final isPositive = (change ?? 0) >= 0;
    final accent = _themeRepo.forOutcome(context.theme, isGood: isPositive);

    return Card(
      padding: context.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceSmall,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(holder.name).semiBold().small(),
              ),
              const SizedBox(width: ThemeRepo.spaceSmall),
              SecondaryBadge(
                child: Text(holder.managerType.getLabel(context.strings)),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.strings.colSharesHeld).muted().xSmall(),
                  Text('$count ($pct)').semiBold().small(),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(context.strings.colMarketValue).muted().xSmall(),
                  Text(value).semiBold().small(),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(context.strings.colQoQChange).muted().xSmall(),
                  if (holder.isNewPosition)
                    const PrimaryBadge(child: Text('NEW'))
                  else if (change == null || change == 0)
                    Text('—').muted().small()
                  else
                    Text(
                      '${change > 0 ? '+' : ''}${_formatRepo.compactCount(change)}',
                    ).small(color: accent),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

