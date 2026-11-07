import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/widgets/column_text.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

const String _prose =
    'Life360 provides a platform for families to coordinate daily life, '
    'share locations and receive safety alerts. It offers these services '
    'through a mobile application on a freemium model, and sells hardware '
    'trackers such as Tile to help people find lost items and pets.\n\n'
    'Its revenue has been driven by subscriptions and by bringing connected '
    'hardware into one household safety platform.';

void main() {
  setUp(() => GetIt.I.registerSingleton(ThemeRepo()));

  void widen(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  tearDown(GetIt.I.reset);

  Future<RenderColumnText> pump(WidgetTester tester, double width) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: Align(
          alignment: Alignment.topLeft,
          // Measured for its natural size first, as the cards it sits in do.
          child: SizedBox(
            width: width,
            child: const IntrinsicHeight(child: ColumnText(_prose)),
          ),
        ),
      ),
    );
    return tester.renderObject<RenderColumnText>(find.byType(ColumnText));
  }

  testWidgets('a wide pane sets the text in columns', (tester) async {
    widen(tester);
    final wide = (await pump(tester, 1200)).size;
    expect(tester.takeException(), isNull);
    final single = (await pump(tester, 360)).size;
    // Shorter than the same text in one column, which is what columns buy,
    // and across the whole width it was given.
    expect(wide.height, lessThan(single.height));
    expect(wide.width, 1200);
  });

  testWidgets('a narrow pane keeps one column', (tester) async {
    final render = await pump(tester, 360);
    expect(tester.takeException(), isNull);
    expect(render.size.width, lessThanOrEqualTo(360));
  });

  testWidgets('an article is set in the system serif', (tester) async {
    await tester.pumpWidget(
      const ShadcnApp(
        home: SizedBox(width: 360, child: ColumnText(_prose, isSerif: true)),
      ),
    );
    final style = tester
        .renderObject<RenderColumnText>(find.byType(ColumnText))
        .style;
    // The system's own family by its own name: not the app font's package
    // path, which a copied style carried and which matched no font at all.
    expect(style.fontFamily, ThemeRepo.serifFamily);
    expect(style.fontFamilyFallback, ThemeRepo.serifFallback);
  });
}
