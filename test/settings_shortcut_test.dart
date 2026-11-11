import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/ui/widgets/settings_button.dart';

const KeyDownEvent _commaDown = KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.comma,
  logicalKey: LogicalKeyboardKey.comma,
  timeStamp: Duration.zero,
);

final Set<LogicalKeyboardKey> _control = {LogicalKeyboardKey.controlLeft};

void main() {
  test('Ctrl+, opens the settings on Linux', () {
    expect(opensSettings(_commaDown, _control, TargetPlatform.linux), isTrue);
    expect(
      opensSettings(_commaDown, {
        LogicalKeyboardKey.controlRight,
      }, TargetPlatform.linux),
      isTrue,
    );
  });

  test('Ctrl+, opens the settings on Windows', () {
    expect(opensSettings(_commaDown, _control, TargetPlatform.windows), isTrue);
  });

  test('on macOS the native menu answers instead', () {
    expect(opensSettings(_commaDown, _control, TargetPlatform.macOS), isFalse);
    expect(
      opensSettings(_commaDown, {
        LogicalKeyboardKey.metaLeft,
      }, TargetPlatform.macOS),
      isFalse,
    );
  });

  test('a comma on its own is only a comma', () {
    expect(opensSettings(_commaDown, {}, TargetPlatform.linux), isFalse);
  });

  test('another modifier held alongside is a different shortcut', () {
    expect(
      opensSettings(_commaDown, {
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
      }, TargetPlatform.linux),
      isFalse,
    );
    expect(
      opensSettings(_commaDown, {
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
      }, TargetPlatform.linux),
      isFalse,
    );
  });

  test('only the key going down opens it, not a repeat or the release', () {
    const repeat = KeyRepeatEvent(
      physicalKey: PhysicalKeyboardKey.comma,
      logicalKey: LogicalKeyboardKey.comma,
      timeStamp: Duration.zero,
    );
    const up = KeyUpEvent(
      physicalKey: PhysicalKeyboardKey.comma,
      logicalKey: LogicalKeyboardKey.comma,
      timeStamp: Duration.zero,
    );
    expect(opensSettings(repeat, _control, TargetPlatform.linux), isFalse);
    expect(opensSettings(up, _control, TargetPlatform.linux), isFalse);
  });

  test('the settings button shows everywhere but macOS', () {
    expect(SettingsButton.isShown(TargetPlatform.linux), isTrue);
    expect(SettingsButton.isShown(TargetPlatform.windows), isTrue);
    expect(SettingsButton.isShown(TargetPlatform.macOS), isFalse);
  });
}
