import 'package:get_it/get_it.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

SettingsRepo get _settingsRepo => GetIt.I.get<SettingsRepo>();

/// App-wide chrome state — currently just which theme the user picked.
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
}
