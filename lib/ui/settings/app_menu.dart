import 'package:flutter/services.dart';

/// The channel the macOS app menu speaks to Flutter on.
///
/// The menu itself is native — `MainMenu.xib`, kept rather than rebuilt with
/// `PlatformMenuBar`, which replaces the whole menu bar and has no stand-in
/// for the system's own Edit menu. All Flutter needs from it is to hear when
/// an item it owns is chosen.
const MethodChannel appMenuChannel = MethodChannel('pickstock/app_menu');

/// What the menu sends when Settings… is chosen, or ⌘, pressed.
const String openSettingsMethod = 'openSettings';
