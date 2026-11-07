import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/research/searxng_search_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/settings/settings_view_model.dart';
import 'package:pickstock/ui/widgets/app_dialog.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pickstock/repo/research/ollama_repo.dart';

ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

const String _dockerDesktopUrl =
    'https://www.docker.com/products/docker-desktop/';
const String _orbStackUrl = 'https://orbstack.dev/download';

/// How often the guide looks for the server while it waits for one. Often
/// enough that the tick appears as the container finishes starting, rarely
/// enough that it is nothing to the machine.
const Duration _pollInterval = Duration(seconds: 3);

/// Opens the guide to running a search server on this Mac.
Future<void> showSearchSetup(BuildContext context) =>
    showAppDialog<void>(context, builder: (_) => const SearchSetupDialog());

/// Walks the reader through running SearXNG on their own machine, which takes
/// away the web search's quota.
///
/// The app is sandboxed: it cannot install Docker or run a command for the
/// reader. What it can do is send them to the download, hand them the one
/// command to paste, and watch for the server to appear — so the guide is
/// three steps, and the third one does itself.
class SearchSetupDialog extends StatefulWidget {
  const SearchSetupDialog({super.key});

  @override
  State<SearchSetupDialog> createState() => _SearchSetupDialogState();
}

class _SearchSetupDialogState extends State<SearchSetupDialog> {
  /// One per opening: a secret nobody needs to remember.
  final String _secret = newSearxngSecret();

  /// Which shell the command is written for, starting from the reader's own.
  SetupShell _shell = SetupShell.fromEnvironment(Platform.environment);

  String get _command => searxngStartCommand(secret: _secret, shell: _shell);

  Timer? _poll;
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<SettingsViewModel>();
    // After the first frame: the check says it has started, and saying so
    // from inside the build that opened the guide is not allowed.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(viewModel.checkLocalSearch()),
    );
    // Keeps looking until it finds the server, so the reader can paste the
    // command and come back to a tick rather than to a button to press.
    _poll = Timer.periodic(_pollInterval, (_) {
      if (viewModel.localSearchStatus == LocalSearchStatus.connected) return;
      unawaited(viewModel.checkLocalSearch());
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _command));
    if (!mounted) return;
    setState(() => _isCopied = true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final status = context.select<SettingsViewModel, LocalSearchStatus>(
      (viewModel) => viewModel.localSearchStatus,
    );
    final isConnected = status == LocalSearchStatus.connected;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: ThemeRepo.settingsDialogWidth,
      ),
      child: Card(
        padding: const EdgeInsets.all(ThemeRepo.spaceLarge),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: ThemeRepo.spaceMedium,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(strings.searchSetupTitle).large().semiBold(),
                  ),
                  Tooltip(
                    tooltip: HintTooltip(strings.settingsClose).call,
                    child: GhostButton(
                      density: ButtonDensity.icon,
                      onPressed: () => closeAppDialog<void>(context),
                      child: const Icon(LucideIcons.x).iconSmall(),
                    ),
                  ),
                ],
              ),
              Text(strings.searchSetupIntro).muted().small(),
              _Step(
                number: 1,
                title: strings.searchSetupDockerTitle,
                body: strings.searchSetupDockerBody,
                isDone: isConnected,
                child: Wrap(
                  spacing: ThemeRepo.spaceSmall,
                  runSpacing: ThemeRepo.spaceSmall,
                  children: [
                    OutlineButton(
                      size: ButtonSize.small,
                      leading: const Icon(LucideIcons.download).iconXSmall(),
                      onPressed: () => _launch(_dockerDesktopUrl),
                      child: const Text('Docker Desktop'),
                    ),
                    OutlineButton(
                      size: ButtonSize.small,
                      leading: const Icon(LucideIcons.download).iconXSmall(),
                      onPressed: () => _launch(_orbStackUrl),
                      child: const Text('OrbStack'),
                    ),
                  ],
                ),
              ),
              _Step(
                number: 2,
                title: strings.searchSetupCommandTitle,
                body: strings.searchSetupCommandBody,
                isDone: isConnected,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: ThemeRepo.spaceSmall,
                  children: [
                    Tabs(
                      key: searchSetupShellKey,
                      index: _shell.index,
                      onChanged: (index) => setState(() {
                        _shell = SetupShell.values[index];
                        // What was copied was the other shell's command.
                        _isCopied = false;
                      }),
                      children: [
                        for (final shell in SetupShell.values)
                          TabItem(child: Text(_shellLabel(shell))),
                      ],
                    ),
                    _CommandBox(command: _command),
                    PrimaryButton(
                      key: searchSetupCopyKey,
                      size: ButtonSize.small,
                      leading: Icon(
                        _isCopied ? LucideIcons.check : LucideIcons.copy,
                      ).iconXSmall(),
                      onPressed: _copy,
                      child: Text(
                        _isCopied
                            ? strings.searchSetupCopied
                            : strings.searchSetupCopy,
                      ),
                    ),
                  ],
                ),
              ),
              _Step(
                number: 3,
                title: strings.searchSetupConnectTitle,
                body: strings.searchSetupConnectBody,
                isDone: isConnected,
                child: const _Connection(),
              ),
              if (isConnected)
                Align(
                  alignment: Alignment.centerRight,
                  child: PrimaryButton(
                    key: searchSetupDoneKey,
                    onPressed: () => closeAppDialog<void>(context),
                    child: Text(strings.searchSetupDone),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shell names, which are the same in every language.
  static String _shellLabel(SetupShell shell) => switch (shell) {
    SetupShell.posix => 'zsh / bash',
    SetupShell.fish => 'fish',
  };

  Future<void> _launch(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// One numbered step: what to do, why, and the controls to do it with.
class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
    required this.isDone,
    required this.child,
  });

  final int number;
  final String title;
  final String body;
  final bool isDone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceMedium,
      children: [
        Container(
          width: ThemeRepo.searchSetupStepSize,
          height: ThemeRepo.searchSetupStepSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? _themeRepo.positive(theme)
                : theme.colorScheme.muted,
          ),
          child: isDone
              ? Icon(
                  LucideIcons.check,
                  color: theme.colorScheme.background,
                ).iconXSmall()
              : Text('$number').xSmall().semiBold(),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: ThemeRepo.spaceSmall,
            children: [
              Text(title).small().semiBold(),
              Text(body).muted().xSmall(),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

/// The command, as text that can be read and selected, not only copied.
class _CommandBox extends StatelessWidget {
  const _CommandBox({required this.command});

  final String command;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ThemeRepo.spaceSmall),
      constraints: const BoxConstraints(
        maxHeight: ThemeRepo.searchSetupCommandMaxHeight,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: theme.borderRadiusMd,
      ),
      child: SingleChildScrollView(child: Text(command).mono().xSmall()),
    );
  }
}

/// Where the guide has got to finding the server, and the address it looks
/// at, which a reader with the server elsewhere can change.
class _Connection extends StatefulWidget {
  const _Connection();

  @override
  State<_Connection> createState() => _ConnectionState();
}

class _ConnectionState extends State<_Connection> {
  late final TextEditingController _url = TextEditingController(
    text: context.read<SettingsViewModel>().localSearchUrl,
  );

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final viewModel = context.read<SettingsViewModel>();
    await viewModel.setLocalSearchUrl(_url.text);
    await viewModel.checkLocalSearch();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final viewModel = context.watch<SettingsViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: ThemeRepo.spaceSmall,
      children: [
        LocalSearchStatusLine(
          status: viewModel.localSearchStatus,
          isChecking: viewModel.isCheckingLocalSearch,
        ),
        Row(
          spacing: ThemeRepo.spaceSmall,
          children: [
            Expanded(
              child: TextField(
                key: searchSetupUrlKey,
                controller: _url,
                placeholder: const Text(defaultSearxngUrl),
                onSubmitted: (_) => _apply(),
              ),
            ),
            OutlineButton(
              key: searchSetupCheckKey,
              size: ButtonSize.small,
              onPressed: viewModel.isCheckingLocalSearch ? null : _apply,
              child: Text(strings.searchSetupCheck),
            ),
          ],
        ),
      ],
    );
  }
}

/// One line saying what was found at the server's address: in the guide and
/// in the settings both, so the two never word it differently.
class LocalSearchStatusLine extends StatelessWidget {
  const LocalSearchStatusLine({
    super.key,
    required this.status,
    required this.isChecking,
  });

  final LocalSearchStatus status;
  final bool isChecking;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final strings = context.strings;
    final (IconData icon, Color color) = switch (status) {
      LocalSearchStatus.connected => (
        LucideIcons.circleCheck,
        _themeRepo.positive(theme),
      ),
      LocalSearchStatus.unknown => (
        LucideIcons.loader,
        theme.colorScheme.mutedForeground,
      ),
      _ => (LucideIcons.circleX, _themeRepo.negative(theme)),
    };
    return Row(
      spacing: ThemeRepo.spaceSmall,
      children: [
        if (isChecking && status != LocalSearchStatus.connected)
          const SizedBox.square(
            dimension: ThemeRepo.inlineSpinnerSize,
            child: CircularProgressIndicator(
              strokeWidth: ThemeRepo.inlineSpinnerStroke,
            ),
          )
        else
          Icon(icon, color: color).iconXSmall(),
        Expanded(
          child: Text(
            describeLocalSearch(status, strings),
            key: localSearchStatusKey,
          ).xSmall(color: color),
        ),
      ],
    );
  }
}

String describeLocalSearch(
  LocalSearchStatus status,
  AppLocalizations strings,
) => switch (status) {
  LocalSearchStatus.unknown => strings.localSearchChecking,
  LocalSearchStatus.connected => strings.localSearchConnected,
  LocalSearchStatus.notRunning => strings.localSearchNotRunning,
  LocalSearchStatus.jsonDisabled => strings.localSearchJsonDisabled,
  LocalSearchStatus.notSearxng => strings.localSearchNotSearxng,
};

/// A small link to the guide, under a failure that it would have prevented.
///
/// Only for the failures it cures — the search refused or missing — and only
/// while local search is off: with it on, the guide has nothing to add.
class SearchSetupLink extends StatelessWidget {
  const SearchSetupLink({super.key, this.onPressed});

  /// In place of opening the guide from here, for a caller inside an overlay
  /// that has to close first.
  final VoidCallback? onPressed;

  /// Whether [failure] is one the guide would have prevented.
  static bool cures(ResearchFailure? failure) =>
      failure == ResearchFailure.searchRefused ||
      failure == ResearchFailure.searchUnavailable ||
      failure == ResearchFailure.searchNotConfigured;

  @override
  Widget build(BuildContext context) {
    final isLocal = context.select<SettingsViewModel, bool>(
      (viewModel) => viewModel.localSearchEnabled,
    );
    if (isLocal) return const SizedBox.shrink();
    return LinkButton(
      key: searchSetupLinkKey,
      size: ButtonSize.small,
      density: ButtonDensity.compact,
      onPressed: onPressed ?? () => showSearchSetup(context),
      child: Text(context.strings.searchSetupLink).xSmall(),
    );
  }
}

const Key searchSetupShellKey = Key('searchSetupShell');
const Key searchSetupCopyKey = Key('searchSetupCopy');
const Key searchSetupDoneKey = Key('searchSetupDone');
const Key searchSetupUrlKey = Key('searchSetupUrl');
const Key searchSetupCheckKey = Key('searchSetupCheck');
const Key searchSetupLinkKey = Key('searchSetupLink');
const Key localSearchStatusKey = Key('localSearchStatus');
