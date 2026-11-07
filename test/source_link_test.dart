import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/widgets/source_link.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

const String _title =
    'Apple Inc. (AAPL) Stock Price, News, Quote & History - Yahoo Finance';
const String _url = 'https://finance.yahoo.com/quote/AAPL/history/';

void main() {
  setUp(() => GetIt.I.registerSingleton(ThemeRepo()));
  tearDown(GetIt.I.reset);

  testWidgets('the tooltip gives the whole title and address, and no more', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ShadcnApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Center(
          child: SourceLinks(
            sources: [(label: _title, url: _url)],
            cik: '0000320193',
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(SourceLink)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // The link itself and the tooltip's title.
    expect(find.text(_title), findsNWidgets(2));
    expect(find.text(_url), findsOneWidget);
    expect(find.textContaining('in your browser'), findsNothing);

    // Neither cut short: the tooltip's text takes as many lines as it needs.
    final inTooltip = tester.widgetList<Text>(find.text(_url)).single;
    final style = DefaultTextStyle.of(tester.element(find.text(_url)));
    expect(inTooltip.maxLines ?? style.maxLines, isNull);
    expect(inTooltip.overflow ?? style.overflow, isNot(TextOverflow.ellipsis));

    // In the tooltip's own light text, not the page's dark text it sits over.
    final page = Theme.of(tester.element(find.byType(SourceLink)));
    final colour = inTooltip.style?.color ?? style.style.color;
    expect(colour?.withValues(alpha: 1), isNot(page.colorScheme.foreground));
  });
}
