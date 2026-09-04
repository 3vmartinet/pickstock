import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/app_view_model.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The page behind a headline, read beside the figures it is about.
///
/// A pane rather than a browser window: the point of the developments panel is
/// to sit next to what the filings say, and a source opened in another
/// application puts the two on different screens. The browser is still one
/// press away, and taking it closes this.
class SourcePane extends StatelessWidget {
  const SourcePane({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.colorScheme.background,
        border: Border(
          left: BorderSide(color: context.theme.colorScheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Toolbar(url: url),
          const Divider(),
          // Keyed on the URL so a second headline loads afresh rather than
          // leaving the first page on screen.
          Expanded(
            child: _Page(key: ValueKey(url), url: url),
          ),
        ],
      ),
    );
  }
}

/// Where it came from, and the two things to do about it.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<AppViewModel>();

    return Padding(
      padding: const EdgeInsets.all(ThemeRepo.spaceSmall),
      child: Row(
        spacing: ThemeRepo.spaceSmall,
        children: [
          Expanded(
            child: Tooltip(
              tooltip: HintTooltip(url).call,
              // The host, not the whole URL: a headline's link runs to a
              // hundred characters of path and tracking, and which publication
              // it is is the part worth reading.
              child: Text(_hostOf(url)).muted().xSmall().singleLine(),
            ),
          ),
          Tooltip(
            tooltip: HintTooltip(context.strings.sourceOpenExternally).call,
            child: GhostButton(
              density: ButtonDensity.icon,
              onPressed: () => _openExternally(viewModel),
              child: const Icon(LucideIcons.externalLink).iconSmall(),
            ),
          ),
          Tooltip(
            tooltip: HintTooltip(context.strings.sourceClose).call,
            child: GhostButton(
              density: ButtonDensity.icon,
              onPressed: viewModel.closeSource,
              child: const Icon(LucideIcons.x).iconSmall(),
            ),
          ),
        ],
      ),
    );
  }

  /// Hands the page to the browser and gives up the pane.
  ///
  /// Closing is the point rather than tidiness: two copies of the same page,
  /// one of them behind the app, is worse than either on its own.
  Future<void> _openExternally(AppViewModel viewModel) async {
    final target = Uri.tryParse(url);
    viewModel.closeSource();
    if (target == null) return;
    await launchUrl(target, mode: LaunchMode.externalApplication);
  }
}

/// `https://apnews.com/article/…` -> `apnews.com`.
String _hostOf(String url) => Uri.tryParse(url)?.host ?? url;

/// The page itself.
///
/// Stateful because the controller is a native object with a lifetime: it is
/// built once for a URL and disposed with it, not rebuilt on every frame the
/// header happens to repaint.
class _Page extends StatefulWidget {
  const _Page({super.key, required this.url});

  final String url;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  WebViewController? _controller;

  /// True where there is no web view to be had — a platform without one, or a
  /// test, where the plugin is not registered. The pane then says where the
  /// page is rather than showing a blank rectangle.
  bool _isUnavailable = false;

  @override
  void initState() {
    super.initState();
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(widget.url));
    } on Object catch (error) {
      // Not a failure worth a red screen: the headline still opens in a
      // browser, and the toolbar above says so.
      logWarning(() => 'No web view available: $error');
      _isUnavailable = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_isUnavailable || controller == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ThemeRepo.spaceLarge),
          child: Text(context.strings.sourceUnavailable)
              .muted()
              .xSmall()
              .textCenter(),
        ),
      );
    }
    return WebViewWidget(controller: controller);
  }
}
