import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/dietitian_tip.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/screens/discover/widgets/dietitian_tips_section.dart';
import 'package:belly_buddy/services/dietitian_tip_service.dart';

import '../../helpers/app_host.dart';
import '../../helpers/dietitian_tip_fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('de_DE', null));

  // 2026-11-26 11:00 local; `createdAt` below is local too (toLocal in
  // the widget is a no-op on a local DateTime).
  final now = DateTime(2026, 11, 26, 11);
  late FakeDietitianTipService service;

  /// Whether the section is visible (its tickers run); an offstage shell
  /// branch or a covered route runs none.
  final visible = ValueNotifier(true);
  tearDown(() => visible.value = true);

  Future<void> pump(WidgetTester tester, List<DietitianTip> tips) async {
    service = FakeDietitianTipService(tips);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('u1'),
          dietitianTipServiceProvider.overrideWithValue(service),
          buddyClockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          theme: AppTheme.theme,
          localizationsDelegates: germanLocalizations,
          supportedLocales: const [germanLocale],
          locale: germanLocale,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, on, _) => TickerMode(
                enabled: on,
                child: const SingleChildScrollView(
                  child: DietitianTipsSection(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const quiet =
      'Diese Tipps kommen von deiner Berater:in, nicht von Belly Buddy.';

  testWidgets('without tips: nothing at all', (tester) async {
    await pump(tester, []);
    expect(find.text('Von deiner Berater:in'), findsNothing);
    expect(find.text(quiet), findsNothing);
  });

  testWidgets('the newest tip large, with sender, profession, time, badge', (
    tester,
  ) async {
    await pump(tester, [testTip(createdAt: DateTime(2026, 11, 26, 9, 12))]);

    expect(find.text('Von deiner Berater:in'), findsOneWidget);
    expect(find.text('Julia Berger'), findsOneWidget);
    expect(
      find.text('Diätolog:in (eigene Angabe) · heute, 09:12'),
      findsOneWidget,
    );
    expect(find.text('JB'), findsOneWidget);
    expect(find.text('Neu'), findsOneWidget);
    expect(find.text('Probier Haferflocken am Morgen.'), findsOneWidget);
    expect(find.text(quiet), findsOneWidget);
  });

  testWidgets('an unknown profession key reads „Andere"', (tester) async {
    await pump(tester, [
      testTip(profession: 'zauberin', createdAt: DateTime(2026, 11, 25, 9, 12)),
    ]);
    expect(
      find.text('Andere (eigene Angabe) · gestern, 09:12'),
      findsOneWidget,
    );
  });

  testWidgets('no „Neu" badge on a seen tip', (tester) async {
    await pump(tester, [testTip(seenAt: DateTime(2026, 11, 26, 10))]);
    expect(find.text('Neu'), findsNothing);
  });

  testWidgets('older tips as a short list; more than five: „Alle anzeigen"', (
    tester,
  ) async {
    await pump(tester, [
      testTip(id: 'n', body: 'newest', createdAt: DateTime(2026, 11, 26, 9)),
      for (var i = 0; i < 6; i++)
        testTip(
          id: 'o$i',
          body: 'older $i',
          createdAt: DateTime(2026, 11, 19 - i, 9),
        ),
    ]);

    expect(find.text('Julia Berger · 19. Nov.'), findsOneWidget);
    expect(find.text('older 0'), findsOneWidget);
    expect(find.text('older 4'), findsOneWidget);
    expect(find.text('older 5'), findsNothing);

    await tester.tap(find.text('Alle anzeigen'));
    await tester.pumpAndSettle();

    expect(find.text('older 5'), findsOneWidget);
    expect(find.text('Alle anzeigen'), findsNothing);
  });

  testWidgets('five older tips: no „Alle anzeigen"', (tester) async {
    await pump(tester, [
      testTip(id: 'n', createdAt: DateTime(2026, 11, 26, 9)),
      for (var i = 0; i < 5; i++)
        testTip(id: 'o$i', createdAt: DateTime(2026, 11, 19 - i, 9)),
    ]);
    expect(find.text('Alle anzeigen'), findsNothing);
  });

  testWidgets('markup and emoji are text, line breaks stay', (tester) async {
    const body = '<b>x</b> 🫶\nzweite Zeile';
    await pump(tester, [testTip(body: body)]);

    expect(find.text(body), findsOneWidget);
    final text = tester.widget<Text>(find.text(body));
    expect(text.data, contains('\n'));
  });

  testWidgets('„Probiere ich" toggles and calls the service', (tester) async {
    await pump(tester, [testTip()]);

    await tester.tap(find.text('Probiere ich'));
    await tester.pumpAndSettle();
    expect(service.tryingCalls, [('t1', true)]);
    expect(find.text('Probiere ich ✓'), findsOneWidget);

    await tester.tap(find.text('Probiere ich ✓'));
    await tester.pumpAndSettle();
    expect(service.tryingCalls.last, ('t1', false));
    expect(find.text('Probiere ich'), findsOneWidget);
  });

  testWidgets('a failing toggle says so and keeps the button', (tester) async {
    await pump(tester, [testTip()]);
    service.failWrite = true;

    await tester.tap(find.text('Probiere ich'));
    await tester.pumpAndSettle();

    expect(find.text(DietitianTipsSection.failedLine), findsOneWidget);
    expect(find.text('Probiere ich'), findsOneWidget);
  });

  Future<void> openRemove(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Mehr').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entfernen'));
    await tester.pumpAndSettle();
  }

  testWidgets('remove: dialog, cancel keeps the tip', (tester) async {
    await pump(tester, [testTip()]);
    await openRemove(tester);

    expect(find.text('Tipp entfernen?'), findsOneWidget);
    expect(
      find.text('Deine Berater:in sieht ihn dann nicht mehr als gelesen.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(service.removed, isEmpty);
    expect(find.text('Probier Haferflocken am Morgen.'), findsOneWidget);
  });

  testWidgets('remove: confirming deletes the tip and the section goes', (
    tester,
  ) async {
    await pump(tester, [testTip()]);
    await openRemove(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Entfernen'),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.removed, ['t1']);
    expect(find.text('Von deiner Berater:in'), findsNothing);
  });

  testWidgets('offstage (no tickers): nothing is stamped until visible', (
    tester,
  ) async {
    visible.value = false;
    await pump(tester, [testTip(id: 'a')]);
    await tester.pump();
    expect(service.seenCalls, isEmpty);

    visible.value = true;
    await tester.pumpAndSettle();
    expect(service.seenCalls, [
      ['a'],
    ]);
  });

  testWidgets('rebuilds of the same load schedule no further stamp', (
    tester,
  ) async {
    await pump(tester, [testTip(id: 'a')]);
    expect(service.seenCalls, hasLength(1));

    // The section rebuilds (hidden and shown again), same load.
    visible.value = false;
    await tester.pump();
    visible.value = true;
    await tester.pumpAndSettle();

    expect(service.seenCalls, hasLength(1));
  });

  testWidgets('shown once: the unseen tips are stamped once', (tester) async {
    await pump(tester, [
      testTip(id: 'a'),
      testTip(id: 'b', seenAt: DateTime(2026, 11, 25)),
    ]);
    await tester.pump();
    await tester.tap(find.text('Probiere ich'));
    await tester.pumpAndSettle();

    expect(service.seenCalls, [
      ['a'],
    ]);
    // The badge stays until the next load.
    expect(find.text('Neu'), findsOneWidget);
  });
}
