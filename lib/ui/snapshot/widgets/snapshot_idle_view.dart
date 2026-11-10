import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/sec/ticker_directory_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/market_leaders_view_model.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/widgets/section_header.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();
TickerDirectoryRepo get _directory => GetIt.I.get<TickerDirectoryRepo>();

/// Width the introduction is held to, so the sentence stays readable on a
/// wide monitor instead of running the full content width.
const double _proseMaxWidth = 480;

/// Width the lists below it are held to: wide enough for a name beside its
/// figures, narrow enough that a row still reads as one line.
const double _sectionMaxWidth = 720;

/// Below this the relative-size bar is dropped, so the name keeps its room.
const double _barMinRowWidth = 520;

const double _barWidth = 120;
const double _barHeight = 6;
const double _capWidth = 96;
const double _recentNameMaxWidth = 180;

/// What the report pane shows before a company is opened: a short
/// introduction, the companies opened last, and the largest companies by
/// market value as somewhere to start.
class SnapshotIdleView extends StatefulWidget {
  const SnapshotIdleView({super.key});

  @override
  State<SnapshotIdleView> createState() => _SnapshotIdleViewState();
}

class _SnapshotIdleViewState extends State<SnapshotIdleView> {
  @override
  void initState() {
    super.initState();
    // Each return to the empty pane brings the ranking up to date, no more
    // often than the prices themselves go stale. After the frame, because
    // starting it notifies, and this is the middle of a build.
    final leaders = context.read<MarketLeadersViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) => leaders.ensureFresh());
  }

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: ThemeRepo.spaceXLarge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: ThemeRepo.spaceXLarge,
        children: [_IdleIntro(), _RecentCompanies(), _MarketLeaders()],
      ),
    );
  }
}

class _IdleIntro extends StatelessWidget {
  const _IdleIntro();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _proseMaxWidth),
      child: Column(
        spacing: ThemeRepo.spaceMedium,
        children: [
          Container(
            padding: const EdgeInsets.all(ThemeRepo.spaceMedium),
            decoration: BoxDecoration(
              color: context.theme.colorScheme.muted,
              borderRadius: context.theme.borderRadiusLg,
            ),
            child: const Icon(LucideIcons.chartLine)
                .iconXLarge()
                .iconMutedForeground(),
          ),
          Column(
            spacing: ThemeRepo.spaceSmall,
            children: [
              Text(context.strings.idleTitle).h3().textCenter(),
              Text(context.strings.idleBody).muted().small().textCenter(),
            ],
          ),
        ],
      ),
    );
  }
}

/// A titled block below the introduction, held to the section width.
class _IdleSection extends StatelessWidget {
  const _IdleSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _sectionMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ThemeRepo.spaceSmall + ThemeRepo.spaceXSmall,
        children: [
          SectionHeader(icon: icon, title: title),
          child,
        ],
      ),
    );
  }
}

/// The companies opened last, most recent first. Nothing at all until one
/// has been opened.
class _RecentCompanies extends StatelessWidget {
  const _RecentCompanies();

  @override
  Widget build(BuildContext context) {
    final tickers = context.select<SnapshotViewModel, List<String>>(
      (viewModel) => viewModel.recentTickers,
    );
    if (tickers.isEmpty) return const SizedBox.shrink();

    return _IdleSection(
      icon: LucideIcons.history,
      title: context.strings.idleRecentTitle,
      child: Wrap(
        spacing: ThemeRepo.spaceSmall,
        runSpacing: ThemeRepo.spaceSmall,
        children: [
          for (final ticker in tickers)
            _RecentChip(ticker: ticker, name: _nameOf(ticker)),
        ],
      ),
    );
  }

  /// The registrant's name, or `null` before the directory is read or once
  /// the symbol has left it.
  static String? _nameOf(String ticker) {
    if (!GetIt.I.isRegistered<TickerDirectoryRepo>()) return null;
    final directory = _directory;
    if (!directory.isLoaded) return null;
    final company = directory.lookup(ticker);
    return company == null || company.name == ticker ? null : company.name;
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.ticker, required this.name});

  final String ticker;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final name = this.name;
    return OutlineButton(
      size: ButtonSize.small,
      onPressed: () => context.read<SnapshotViewModel>().search(ticker),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: ThemeRepo.spaceSmall,
        children: [
          Text(ticker).mono().semiBold(),
          if (name != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _recentNameMaxWidth),
              child: Text(name).muted().singleLine().ellipsis(),
            ),
        ],
      ),
    );
  }
}

/// The largest companies by market value, ranked, each with a bar for its
/// size against the largest.
class _MarketLeaders extends StatelessWidget {
  const _MarketLeaders();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MarketLeadersViewModel>();
    final leaders = viewModel.leaders;
    if (leaders.isEmpty && !viewModel.isLoading) {
      return const SizedBox.shrink();
    }

    final theme = context.theme;
    final rows = leaders.isEmpty
        ? [for (var i = 0; i < marketLeaderCount; i++) const _LeaderSkeleton()]
        : [
            for (final (index, leader) in leaders.indexed)
              _LeaderRow(
                rank: index + 1,
                leader: leader,
                share: leader.marketCap / leaders.first.marketCap,
              ),
          ];

    final newest = leaders.isEmpty
        ? null
        : leaders
              .map((leader) => leader.quote.asOf)
              .reduce((a, b) => a.isAfter(b) ? a : b);

    return _IdleSection(
      icon: LucideIcons.landmark,
      title: context.strings.idleLeadersTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ThemeRepo.spaceSmall,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.border),
              borderRadius: theme.borderRadiusLg,
            ),
            child: ClipRRect(
              borderRadius: theme.borderRadiusLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, row) in rows.indexed) ...[
                    if (index > 0) const Divider(),
                    row,
                  ],
                ],
              ),
            ),
          ),
          if (newest != null)
            Text(
              context.strings.idleLeadersNote(_formatRepo.timeOrDate(newest)),
            ).muted().xSmall(),
        ],
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.rank,
    required this.leader,
    required this.share,
  });

  final int rank;
  final MarketLeader leader;

  /// This company's market value as a fraction of the largest one's.
  final double share;

  @override
  Widget build(BuildContext context) {
    final Company company = leader.company;
    return GhostButton(
      shape: ButtonShape.rectangle,
      alignment: AlignmentDirectional.centerStart,
      onPressed: () => context.read<SnapshotViewModel>().search(company.ticker),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          spacing: ThemeRepo.spaceMedium,
          children: [
            SizedBox(
              width: ThemeRepo.reportRankWidth,
              child: Text('$rank').muted().xSmall().mono(),
            ),
            SizedBox(
              width: ThemeRepo.reportTickerWidth,
              child: Text(company.ticker)
                  .mono()
                  .small()
                  .semiBold()
                  .singleLine(),
            ),
            Expanded(child: Text(company.name).small().singleLine().ellipsis()),
            if (constraints.maxWidth >= _barMinRowWidth) _ShareBar(share),
            SizedBox(
              width: _capWidth,
              child: Text(_formatRepo.marketValue(leader.marketCap))
                  .small()
                  .semiBold()
                  .mono()
                  .singleLine()
                  .textEnd(),
            ),
          ],
        ),
      ),
    );
  }
}

/// How large a company is next to the largest, as a filled track.
class _ShareBar extends StatelessWidget {
  const _ShareBar(this.share);

  final double share;

  @override
  Widget build(BuildContext context) {
    final colours = context.theme.colorScheme;
    return SizedBox(
      width: _barWidth,
      height: _barHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colours.muted,
          borderRadius: BorderRadius.circular(_barHeight / 2),
        ),
        child: FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: share.clamp(0.02, 1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colours.primary,
              borderRadius: BorderRadius.circular(_barHeight / 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row-shaped stand-in while the stored prices are read.
class _LeaderSkeleton extends StatelessWidget {
  const _LeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ThemeRepo.spaceMedium,
          vertical: ThemeRepo.spaceSmall + ThemeRepo.spaceXSmall,
        ),
        child: const Row(
          spacing: ThemeRepo.spaceMedium,
          children: [
            SizedBox(width: ThemeRepo.reportRankWidth, child: Text('00')),
            SizedBox(width: ThemeRepo.reportTickerWidth, child: Text('TICK')),
            Expanded(child: Text('Placeholder company name')),
            SizedBox(width: _capWidth, child: Text(r'$0.00T')),
          ],
        ).asSkeleton(),
      ),
    );
  }
}
