import 'package:shadcn_flutter/shadcn_flutter.dart';

/// App-wide chrome state — currently just which theme the user picked.
class AppViewModel extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// Flips to the opposite of whatever is on screen right now, so the first
  /// tap always visibly changes something even from [ThemeMode.system].
  void toggleTheme(Brightness current) {
    _themeMode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}
