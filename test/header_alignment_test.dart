import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/browse/widgets/sector_filter_row.dart';
import 'package:pickstock/ui/browse/widgets/ticker_filter_bar.dart';
import 'package:pickstock/ui/widgets/brand_mark.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

/// Wide enough for the list and the report side by side.
const Size _wideSize = Size(1440, 900);

/// Phone width, where the gutter tightens.
const Size _compactSize = Size(420, 900);

void main() {
  late AppDatabase database;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    database = await registerTestDependencies(withFinancials: true);
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  Future<void> openHome(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
  }

  /// Every row of the main screen, top to bottom, that the eye reads as a
  /// column: the mark, the filter, the sector chips and the first tile.
  Map<String, Rect> rowsOf(WidgetTester tester) => {
    'brand mark': tester.getRect(find.byType(BrandMark)),
    'filter field': tester.getRect(find.byType(TextField).first),
    'sector chip': tester.getRect(
      find
          .descendant(
            of: find.byType(SectorFilterRow),
            matching: find.byType(Button),
          )
          .first,
    ),
    'first tile': tester.getRect(
      find
          .descendant(of: find.byType(GridView), matching: find.byType(Button))
          .first,
    ),
  };

  testWidgets('every header row starts on the same left edge', (tester) async {
    await openHome(tester, _wideSize);

    final rows = rowsOf(tester);
    for (final row in rows.entries) {
      expect(
        row.value.left,
        ThemeRepo.pageGutter,
        reason: '${row.key} does not start on the page gutter',
      );
    }
  });

  testWidgets('and on a narrow window', (tester) async {
    await openHome(tester, _compactSize);

    final rows = rowsOf(tester);
    for (final row in rows.entries) {
      expect(
        row.value.left,
        ThemeRepo.pageGutter,
        reason: '${row.key} does not start on the page gutter',
      );
    }
  });

  testWidgets('the sector chips are not sitting on the divider', (
    tester,
  ) async {
    await openHome(tester, _wideSize);

    // Measured from the bar's own controls rather than from the text field:
    // the bar is a `Wrap`, and in a list column this narrow the field sits on
    // the first of two runs with the count and the toggles below it. The
    // field's bottom is then a run short of where the bar actually ends.
    final bar = tester.getRect(
      find.descendant(
        of: find.byType(TickerFilterBar),
        matching: find.byType(Wrap),
      ),
    );
    // Top and bottom measured from different chips for the same reason the
    // bar is measured from its controls: the chip row is a `Wrap` too, and a
    // window this narrow puts the last chips on a run of their own. The first
    // chip is the top of the row and the last one the bottom of it.
    final chips = find.descendant(
      of: find.byType(SectorFilterRow),
      matching: find.byType(Button),
    );
    final firstChip = tester.getRect(chips.first);
    final lastChip = tester.getRect(chips.last);
    final divider = tester.getRect(find.byType(Divider).first);

    final above = firstChip.top - bar.bottom;
    final below = divider.top - lastChip.bottom;

    // Even space either side of the row. The row used to carry no vertical
    // padding at all, which left the divider a pixel under the chips.
    expect(above, greaterThanOrEqualTo(ThemeRepo.spaceMedium));
    expect(below, greaterThanOrEqualTo(ThemeRepo.spaceMedium));
    expect(above, closeTo(below, 1));
  });

  testWidgets('the divider has the same air above it as below', (tester) async {
    await openHome(tester, _wideSize);

    // Measured from the chip row rather than a chip: the button sits a pixel
    // inside its own row, which is the widget's box and not the padding.
    final chipRow = tester.getRect(find.byType(SectorFilterRow));
    final divider = tester.getRect(find.byType(Divider).first);
    final firstTile = tester.getRect(
      find
          .descendant(of: find.byType(GridView), matching: find.byType(Button))
          .first,
    );

    expect(divider.top - chipRow.bottom, 0);
    // The chip row's own bottom padding, and the grid's top padding, are the
    // same value: a divider with more air on one side reads as belonging to
    // whichever block is closer.
    expect(firstTile.top - divider.bottom, ThemeRepo.pageGutter);
  });

  testWidgets('the grid is inset the same amount on every side', (
    tester,
  ) async {
    await openHome(tester, _wideSize);

    final grid = tester.getRect(find.byType(GridView));
    final divider = tester.getRect(find.byType(Divider).first);
    final firstTile = tester.getRect(
      find
          .descendant(of: find.byType(GridView), matching: find.byType(Button))
          .first,
    );

    // The margin used to be twice as wide as it was tall, which read as the
    // content being pushed right rather than centred in its pane.
    expect(firstTile.left - grid.left, ThemeRepo.pageGutter);
    expect(firstTile.top - divider.bottom, ThemeRepo.pageGutter);
  });
}
