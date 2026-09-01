import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Size _wideSize = Size(1600, 1200);

void main() {
  group('sentence splitting', () {
    test('breaks on sentence ends', () {
      expect(splitIntoSentences('One thing. Then another.'), [
        'One thing.',
        'Then another.',
      ]);
    });

    test('leaves decimals and amounts alone', () {
      // A full stop inside a figure is not the end of a sentence.
      expect(splitIntoSentences(r'It kept $3.71T of it.'), [
        r'It kept $3.71T of it.',
      ]);
      expect(splitIntoSentences('Another 2.5 years of cash.'), [
        'Another 2.5 years of cash.',
      ]);
    });

    test('splits before a figure that opens a sentence', () {
      expect(splitIntoSentences(r'It is dear. $250.00 is above the range.'), [
        'It is dear.',
        r'$250.00 is above the range.',
      ]);
    });

    test('a single sentence stays one line', () {
      expect(splitIntoSentences('Add to a list'), ['Add to a list']);
    });
  });

  group('on screen', () {
    late AppDatabase database;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      database = await registerTestDependencies(withFinancials: true);
    });

    tearDown(() async {
      await database.close();
      await GetIt.I.reset();
    });

    testWidgets('wraps instead of running the width of the window', (
      tester,
    ) async {
      tester.view
        ..physicalSize = _wideSize
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const PickStockApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apple Inc.'));
      await tester.pumpAndSettle();

      // The net-debt hint is the longest in the app, and used to render as one
      // line spanning the whole window.
      final info = find.byIcon(LucideIcons.info);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(info.last));
      await tester.pumpAndSettle();

      final tip = find.byType(HintTooltip);
      expect(tip, findsOneWidget);

      // The cap applies to the text; the container adds its own padding around
      // it. What matters is that a long hint no longer spans the window.
      final width = tester.getRect(tip).width;
      expect(width, lessThan(_wideSize.width / 3));
      expect(
        width,
        lessThanOrEqualTo(ThemeRepo.tooltipMaxWidth + ThemeRepo.spaceXXLarge),
      );

      // And that it grew downwards: one line per sentence.
      expect(
        find.descendant(of: tip, matching: find.byType(Text)),
        findsNWidgets(3),
      );
    });
  });
}
