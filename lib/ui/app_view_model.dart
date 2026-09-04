import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

SettingsRepo get _settingsRepo => GetIt.I.get<SettingsRepo>();

/// App-wide chrome state: the theme, and how the window is divided up.
class AppViewModel extends ChangeNotifier {
  /// Seeded from the setting read before the first frame, so the app opens in
  /// the chosen theme rather than in the system one.
  ThemeMode _themeMode = _settingsRepo.themeMode;
  ThemeMode get themeMode => _themeMode;

  /// Flips to the opposite of whatever is on screen right now, so the first
  /// tap always visibly changes something even from [ThemeMode.system].
  void toggleTheme(Brightness current) {
    _themeMode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    _settingsRepo.setThemeMode(_themeMode);
  }

  /// How wide the list sits beside the report.
  ///
  /// Clamped to what the divider itself allows: a width remembered from a
  /// build with different limits should open at the nearest allowed one rather
  /// than at something the divider cannot be dragged back to.
  double get masterPaneWidth =>
      (_settingsRepo.masterPaneWidth ?? ThemeRepo.masterListWidth).clamp(
        ThemeRepo.masterListMinWidth,
        ThemeRepo.masterListMaxWidth,
      );

  String? _openedSource;

  /// The page open in the pane on the right, or `null` when it is closed.
  String? get openedSource => _openedSource;

  /// Whose report the open page was reached from.
  ///
  /// Held so the pane cannot outlive it: an article about Apple beside
  /// NVIDIA's figures is worse than no article, because it reads as though it
  /// were about NVIDIA.
  String? _sourceCik;

  /// Opens [url] beside the report rather than in a browser.
  ///
  /// A source read next to the figures it is about beats one read in another
  /// application with the figures behind it — which is the whole reason the
  /// pane exists rather than a `launchUrl` and be done with it.
  void openSource(String url, {required String cik}) {
    if (url == _openedSource && cik == _sourceCik) return;
    _openedSource = url;
    _sourceCik = cik;
    notifyListeners();
  }

  void closeSource() {
    if (_openedSource == null) return;
    _openedSource = null;
    _sourceCik = null;
    notifyListeners();
  }

  /// Closes the pane when the reader moves to another company.
  ///
  /// A no-op while the company is the one the page was opened from, so this is
  /// safe to push in from a build — which is where it comes from, the two view
  /// models being siblings.
  void applySelectedCompany(String? cik) {
    if (_openedSource == null || cik == _sourceCik) return;
    _openedSource = null;
    _sourceCik = null;
    // Deferred: this is pushed in from a build, and notifying listeners while
    // the tree is building rebuilds widgets that have already been laid out
    // this frame.
    scheduleMicrotask(notifyListeners);
  }

  /// Remembers where the divider was let go of.
  ///
  /// No [notifyListeners]: the pane is already the width being recorded, and
  /// rebuilding the panel that reported it would be a rebuild to change
  /// nothing. It is read again on the next launch, and on the next layout that
  /// brings the divider back.
  void rememberMasterPaneWidth(double width) =>
      _settingsRepo.setMasterPaneWidth(width);
}
