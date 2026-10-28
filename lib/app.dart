import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/app_route.dart';
import 'package:pickstock/ui/app_view_model.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/ingest_view_model.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/report/jobs_view_model.dart';
import 'package:pickstock/ui/report/research_queue.dart';
import 'package:pickstock/ui/settings/app_menu.dart';
import 'package:pickstock/ui/settings/settings_view_model.dart';
import 'package:pickstock/ui/settings/widgets/settings_dialog.dart';
import 'package:pickstock/ui/watchlist/watchlist_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

class PickStockApp extends StatelessWidget {
  const PickStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppViewModel()),
        ChangeNotifierProvider(create: (_) => IngestViewModel()),
        ChangeNotifierProvider(create: (_) => SettingsViewModel()),
        // Above the router: browsing the directory and coming back must not
        // discard the report already on screen.
        ChangeNotifierProvider(create: (_) => SnapshotViewModel()),
        // Lazily built, so it reads the directory only once the ingest gate
        // has let the app through — and kept alive afterwards so returning to
        // the list restores its ordering, filter and scroll position.
        ChangeNotifierProvider(create: (_) => BrowseViewModel()),
        // Also above the router: a company starred from its own screen has to
        // be starred on the list the moment you go back to it.
        ChangeNotifierProvider(create: (_) => WatchlistViewModel()),
        // Also above the router: a scan takes tens of minutes, and navigating
        // away from the list that started it must not abandon it.
        ChangeNotifierProvider(create: (_) => JobsViewModel()),
        // Owned by the locator rather than created here: the report models
        // reach it without a context, and it must outlive every screen that
        // puts a question into it.
        ChangeNotifierProvider<ResearchQueue>.value(
          value: GetIt.I.get<ResearchQueue>(),
        ),
      ],
      child: const _PickStockAppView(),
    );
  }
}

class _PickStockAppView extends StatefulWidget {
  const _PickStockAppView();

  @override
  State<_PickStockAppView> createState() => _PickStockAppViewState();
}

class _PickStockAppViewState extends State<_PickStockAppView> {
  /// The navigator every route sits in, held so the app menu can open the
  /// settings over whichever screen is showing: the menu speaks to the app,
  /// not to a screen, and has no context of its own.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey();

  /// Whether the settings are already open, so a second ⌘, does not stack a
  /// second copy on the first.
  bool _isSettingsOpen = false;

  /// The update the screens below were last brought up to date with.
  int _dataRevision = 0;

  late final IngestViewModel _ingest = context.read<IngestViewModel>();

  @override
  void initState() {
    super.initState();
    // Here rather than in a screen: an update lands whichever screen is up,
    // and the list and the report both outlive the screens that show them.
    _ingest.addListener(_onIngestChanged);
    appMenuChannel.setMethodCallHandler((call) async {
      // Not awaited: the dialog's future ends when it is closed, and the
      // menu's call would be left unanswered for as long as it is open.
      if (call.method == openSettingsMethod) unawaited(_openSettings());
    });
  }

  @override
  void dispose() {
    appMenuChannel.setMethodCallHandler(null);
    _ingest.removeListener(_onIngestChanged);
    super.dispose();
  }

  /// Brings what is on screen up to the figures an update has just swapped
  /// in.
  ///
  /// The blocking load used to do this by accident — shutting the app tore
  /// every screen down and built it again. Loaded in the background, the
  /// screens stay up, so the list and the open report are told instead.
  void _onIngestChanged() {
    final revision = _ingest.dataRevision;
    if (revision == _dataRevision) return;
    _dataRevision = revision;
    context.read<BrowseViewModel>().ensureCurrent();
    unawaited(context.read<SnapshotViewModel>().reloadFigures());
  }

  Future<void> _openSettings() async {
    // The overlay's context rather than the navigator's: a dialog needs an
    // overlay above it, and the navigator's own context sits above its own.
    final context = _navigatorKey.currentState?.overlay?.context;
    if (context == null || _isSettingsOpen) return;
    _isSettingsOpen = true;
    try {
      await showSettings(context);
    } finally {
      _isSettingsOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppViewModel, ThemeMode>(
      (viewModel) => viewModel.themeMode,
    );

    return ShadcnApp(
      title: _appTitle,
      theme: _themeRepo.lightTheme,
      darkTheme: _themeRepo.darkTheme,
      themeMode: themeMode,
      navigatorKey: _navigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: AppRoute.home.path,
      routes: AppRoute.routes,
      // Nothing to say: the corner ribbon covers the app's own chrome and
      // tells the only person who ever sees it something they already know.
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Window and tab title. Not user-facing copy inside the app, so it stays out
/// of the ARB bundle, which is per-locale and unavailable this high up.
const String _appTitle = 'PickStock';
