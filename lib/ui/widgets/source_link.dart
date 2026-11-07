import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/app_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

/// A line of text that opens the page it came from.
///
/// Muted until the pointer is over it and the accent colour under it, which is
/// how the rest of the app marks something that will do something — and the
/// only way a line of text among other lines can say it is more than a
/// caption.
///
/// Opens beside the report rather than in a browser: a source is worth reading
/// next to the figures it is about. The pane's own toolbar hands it to the
/// browser for anyone who would rather have it there.
class SourceLink extends StatefulWidget {
  const SourceLink({
    super.key,
    required this.label,
    required this.url,
    required this.cik,
    this.fontSize = ThemeRepo.eventFontSize,
  });

  final String label;
  final String url;

  /// Whose report the link was read from, carried so the pane it opens cannot
  /// outlive that report.
  final String cik;

  final double fontSize;

  @override
  State<SourceLink> createState() => _SourceLinkState();
}

class _SourceLinkState extends State<SourceLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Tooltip(
      // The whole title and the whole address: the link itself is often cut
      // short by the width it has, and this is where the rest of it goes.
      tooltip: (_) => _LinkTooltip(label: widget.label, url: widget.url),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: () => context.read<AppViewModel>().openSource(
            widget.url,
            cik: widget.cik,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: widget.fontSize,
              color: _isHovered
                  ? theme.colorScheme.primary
                  : theme.colorScheme.mutedForeground,
              // Underlined only under the pointer, as shadcn's own links are:
              // several underlined lines together would read as a menu.
              decoration: _isHovered ? TextDecoration.underline : null,
              decorationColor: theme.colorScheme.primary,
            ),
          ).singleLine().ellipsis(),
        ),
      ),
    );
  }
}

/// A link's title over its address, both in full.
///
/// Wrapped onto as many lines as they need, never cut short: the tooltip is
/// the one place a shortened link can be read whole. Set explicitly rather
/// than inherited, so no ellipsis from the text it hovers over carries in.
class _LinkTooltip extends StatelessWidget {
  const _LinkTooltip({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.typography;

    return TooltipContainer(
      // A fresh text default rather than the inherited one: a [Text] given no
      // line limit falls back to its ancestors', and the link this hovers over
      // is a single line ending in an ellipsis. Read from inside the
      // container, so it keeps the light text the tooltip sets on its dark
      // fill rather than the page's dark text from outside it.
      child: Builder(
        builder: (inside) => DefaultTextStyle(
          style: DefaultTextStyle.of(inside).style,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ThemeRepo.tooltipMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: ThemeRepo.spaceXSmall,
              children: [
                // The address alone where there is no title beyond it.
                if (label != url) Text(label, style: typography.semiBold),
                Text(
                  url,
                  // A shade back from the title, which is what the reader
                  // was looking for; the address is there to check it by.
                  style: typography.xSmall.copyWith(
                    color: DefaultTextStyle.of(inside).style.color?.withValues(
                      alpha: ThemeRepo.linkTooltipAddressOpacity,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One page cited in a list of them.
typedef SourceLinkItem = ({String label, String url});

/// Several sources, side by side and wrapping onto new rows as the width
/// runs out, each cut short with an ellipsis.
///
/// One a line, a list of page titles ran to a dozen lines of mostly the same
/// few words — the site's name, the article's — for what is a list of
/// references. Cut to a common width they sit several to a row; the full
/// title is in each one's tooltip, where it already was.
class SourceLinks extends StatelessWidget {
  const SourceLinks({super.key, required this.sources, required this.cik});

  final Iterable<SourceLinkItem> sources;

  /// Whose report the links were read from; see [SourceLink.cik].
  final String cik;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ThemeRepo.spaceMedium,
      runSpacing: ThemeRepo.spaceXSmall,
      children: [
        for (final source in sources)
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ThemeRepo.sourceLinkMaxWidth,
            ),
            // A link glyph at the head of each, so where one ends and the
            // next begins is plain even when both run to an ellipsis.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: ThemeRepo.spaceXSmall,
              children: [
                const Icon(LucideIcons.link).iconXSmall().iconMutedForeground(),
                Flexible(
                  child: SourceLink(
                    label: source.label,
                    url: source.url,
                    cik: cik,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The pages an answer was read from, under a "Sources" label: the one way
/// a model's sources are listed, on the overview's insights and on the
/// framework's answers alike.
///
/// Listed in the open rather than folded away: set side by side and cut to a
/// common width they take a line or two, which is less than the row a fold
/// takes to say how many there are.
class SourcesList extends StatelessWidget {
  const SourcesList({super.key, required this.sources, required this.cik});

  final Iterable<SearchResult> sources;

  /// Whose report the links were read from; see [SourceLink.cik].
  final String cik;

  @override
  Widget build(BuildContext context) {
    // One link per page, however many times the model cited it.
    final unique = {for (final source in sources) source.url: source};
    if (unique.isEmpty) return const SizedBox.shrink();

    // A line's worth of room above, so the list reads as a section of its
    // own rather than as the last lines of the answer.
    return Padding(
      padding: const EdgeInsets.only(top: ThemeRepo.spaceMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceSmall,
        children: [
          Text(context.strings.insightSources).muted().xSmall().semiBold(),
          SourceLinks(
            sources: [
              for (final source in unique.values)
                (
                  label: source.title.isEmpty ? source.url : source.title,
                  url: source.url,
                ),
            ],
            cik: cik,
          ),
        ],
      ),
    );
  }
}
