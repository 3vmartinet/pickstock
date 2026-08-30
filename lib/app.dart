import 'package:get_it/get_it.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/app_route.dart';
import 'package:pickstock/ui/app_view_model.dart';
import 'package:pickstock/ui/ingest_view_model.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
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
        // Above the router: browsing the directory and coming back must not
        // discard the report already on screen.
        ChangeNotifierProvider(create: (_) => SnapshotViewModel()),
      ],
      child: const _PickStockAppView(),
    );
  }
}

class _PickStockAppView extends StatelessWidget {
  const _PickStockAppView();

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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: AppRoute.snapshot.path,
      routes: AppRoute.routes,
    );
  }
}

/// Window and tab title. Not user-facing copy inside the app, so it stays out
/// of the ARB bundle, which is per-locale and unavailable this high up.
const String _appTitle = 'PickStock';
