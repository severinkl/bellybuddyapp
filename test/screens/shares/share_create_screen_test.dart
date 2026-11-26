// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/models/data_share.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/share_launcher_provider.dart';
import 'package:belly_buddy/providers/shares_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/shares/share_create_screen.dart';
import 'package:belly_buddy/screens/shares/shares_screen.dart';
import 'package:belly_buddy/services/share_secrets_store.dart';
import 'package:belly_buddy/services/share_service.dart';

import '../../helpers/app_host.dart';
import '../../helpers/share_fakes.dart';

class _RecordingService extends FakeShareService {
  final List<NewShare> created = [];
  Object? failWith;

  /// While set, a create waits for it.
  Completer<void>? gate;

  @override
  Future<CreatedShare> create(NewShare share) async {
    await gate?.future;
    if (failWith != null) throw failWith!;
    created.add(share);
    return super.create(share);
  }
}

void main() {
  late _RecordingService service;
  late GoRouter router;
  late ProviderContainer container;

  setUpAll(() => initializeDateFormatting('de_DE', null));

  Future<void> pump(
    WidgetTester tester, {
    String? savedName,
    bool openCreate = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    if (savedName != null) {
      await ShareSecretsStore(
        userId: () => 'u1',
      ).rememberDisplayName(savedName);
    }
    tester.view.physicalSize = const Size(393, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    service = _RecordingService();
    container = ProviderContainer.test(
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        shareServiceProvider.overrideWithValue(service),
        buddyClockProvider.overrideWithValue(() => DateTime(2026, 11, 26, 12)),
        shareLauncherProvider.overrideWithValue((_, _) async {}),
      ],
    );
    router = GoRouter(
      initialLocation: RoutePaths.shares,
      routes: [
        GoRoute(
          path: RoutePaths.shares,
          builder: (_, _) => const SharesScreen(),
          routes: [
            GoRoute(path: 'new', builder: (_, _) => const ShareCreateScreen()),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: germanRouterApp(router),
      ),
    );
    await tester.pumpAndSettle();
    if (!openCreate) return;
    unawaited(router.push(RoutePaths.shareCreate));
    await tester.pumpAndSettle();
  }

  bool switchOn(WidgetTester tester, String label) => tester
      .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, label))
      .value;

  bool switchEnabled(WidgetTester tester, String label) =>
      tester
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, label))
          .onChanged !=
      null;

  Finder button() => find.widgetWithText(ElevatedButton, 'Link erstellen');

  bool buttonEnabled(WidgetTester tester) =>
      tester.widget<ElevatedButton>(button()).onPressed != null;

  Future<void> tapSwitch(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(SwitchListTile, label));
    await tester.pump();
  }

  Future<void> typeName(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextField), name);
    await tester.pump();
  }

  testWidgets('defaults and the fixed texts', (tester) async {
    await pump(tester);
    for (final t in [
      'Mit Berater:in teilen',
      'Wer deinen Link und Code hat, kann dein Tagebuch ansehen, aber nichts '
          'ändern.',
      'Dein Name in der Ansicht',
      'Zeitraum',
      '14 Tage',
      'Alles',
      'Was wird geteilt?',
      'Link gültig für',
      '7 Tage',
      '90 Tage',
      'Muster zeigen immer die letzten 30 Tage.',
      'Das sind Gesundheitsdaten. Neue Einträge erscheinen automatisch. Du '
          'kannst die Freigabe jederzeit beenden.',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('30 Tage'), findsNWidgets(2));
    for (final l in [
      'Mahlzeiten und Zutaten',
      'Getränke',
      'Bauchgefühl und Symptome',
      'Klo-Einträge',
      'Muster und Unverträglichkeiten',
    ]) {
      expect(switchOn(tester, l), isTrue, reason: l);
    }
    expect(switchOn(tester, 'Fotos der Mahlzeiten'), isFalse);
    expect(find.text('Braucht Bauchgefühl'), findsNothing);
    expect(buttonEnabled(tester), isFalse);
  });

  testWidgets('the name is prefilled from the last one', (tester) async {
    await pump(tester, savedName: 'Dr. Muster');
    expect(find.text('Dr. Muster'), findsOneWidget);
    expect(buttonEnabled(tester), isTrue);
  });

  testWidgets('Fotos follows Mahlzeiten, and does not come back by itself', (
    tester,
  ) async {
    await pump(tester);
    await tapSwitch(tester, 'Fotos der Mahlzeiten');
    expect(switchOn(tester, 'Fotos der Mahlzeiten'), isTrue);
    await tapSwitch(tester, 'Mahlzeiten und Zutaten');
    expect(switchOn(tester, 'Fotos der Mahlzeiten'), isFalse);
    expect(switchEnabled(tester, 'Fotos der Mahlzeiten'), isFalse);
    await tapSwitch(tester, 'Mahlzeiten und Zutaten');
    expect(switchEnabled(tester, 'Fotos der Mahlzeiten'), isTrue);
    expect(switchOn(tester, 'Fotos der Mahlzeiten'), isFalse);
  });

  testWidgets('Muster follows Bauchgefühl, with its line', (tester) async {
    await pump(tester);
    await tapSwitch(tester, 'Bauchgefühl und Symptome');
    expect(switchOn(tester, 'Muster und Unverträglichkeiten'), isFalse);
    expect(switchEnabled(tester, 'Muster und Unverträglichkeiten'), isFalse);
    expect(find.text('Braucht Bauchgefühl'), findsOneWidget);
    await tapSwitch(tester, 'Bauchgefühl und Symptome');
    expect(switchEnabled(tester, 'Muster und Unverträglichkeiten'), isTrue);
    expect(switchOn(tester, 'Muster und Unverträglichkeiten'), isFalse);
    expect(find.text('Braucht Bauchgefühl'), findsNothing);
  });

  testWidgets('the button needs a trimmed name and one data switch', (
    tester,
  ) async {
    await pump(tester);
    await typeName(tester, '   ');
    expect(buttonEnabled(tester), isFalse);
    await typeName(tester, ' Dr. A ');
    expect(buttonEnabled(tester), isTrue);
    for (final l in [
      'Mahlzeiten und Zutaten',
      'Getränke',
      'Bauchgefühl und Symptome',
      'Klo-Einträge',
    ]) {
      await tapSwitch(tester, l);
    }
    // Muster went off with Bauchgefühl: all five are off now.
    expect(buttonEnabled(tester), isFalse);
    await tapSwitch(tester, 'Getränke');
    expect(buttonEnabled(tester), isTrue);
  });

  testWidgets('submits the form and opens the sheet over the list', (
    tester,
  ) async {
    await pump(tester);
    await typeName(tester, ' Dr. A ');
    await tester.tap(find.text('14 Tage'));
    await tester.tap(find.text('90 Tage'));
    await tester.tap(find.text('Alles').first);
    await tapSwitch(tester, 'Fotos der Mahlzeiten');
    await tapSwitch(tester, 'Klo-Einträge');
    await tester.tap(button());
    await tester.pumpAndSettle();

    final s = service.created.single;
    expect(s.displayName, 'Dr. A');
    expect(s.period, SharePeriod.all);
    expect(s.validDays, 90);
    expect(
      [s.meals, s.drinks, s.gut, s.toilet, s.patterns, s.photos],
      [true, true, true, false, true, true],
    );
    expect(find.text('Deine Freigaben'), findsOneWidget);
    expect(find.text('Dein Link ist bereit'), findsOneWidget);
    expect(find.text('https://example.test/s/abc'), findsOneWidget);
    expect(find.text('482 913'), findsOneWidget);

    // Closing the sheet leaves the list.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Dein Link ist bereit'), findsNothing);
    expect(find.text('Deine Freigaben'), findsOneWidget);
    expect(find.byType(ShareCreateScreen), findsNothing);
    // Exactly one list is in the stack.
    expect(find.byType(SharesScreen, skipOffstage: false), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('a 409 message is shown and the form is kept', (tester) async {
    await pump(tester);
    service.failWith = const ShareException(
      status: 409,
      message: 'Du hast schon zu viele Freigaben.',
    );
    await typeName(tester, 'Dr. A');
    await tapSwitch(tester, 'Getränke');
    await tester.tap(button());
    await tester.pumpAndSettle();
    expect(find.text('Du hast schon zu viele Freigaben.'), findsOneWidget);
    expect(find.byType(ShareCreateScreen), findsOneWidget);
    expect(find.text('Dr. A'), findsOneWidget);
    expect(switchOn(tester, 'Getränke'), isFalse);
    expect(service.created, isEmpty);
    expect(buttonEnabled(tester), isTrue);
  });

  testWidgets('a generic failure shows the usual text', (tester) async {
    await pump(tester);
    service.failWith = Exception('offline');
    await typeName(tester, 'Dr. A');
    await tester.tap(button());
    await tester.pumpAndSettle();
    expect(
      find.text('Das hat nicht geklappt. Versuch es später nochmal.'),
      findsOneWidget,
    );
    expect(find.byType(ShareCreateScreen), findsOneWidget);
    expect(find.text('Dr. A'), findsOneWidget);
  });

  testWidgets('the name field carries its heading as semantic label', (
    tester,
  ) async {
    await pump(tester);
    expect(find.bySemanticsLabel('Dein Name in der Ansicht'), findsWidgets);
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byType(TextField)).label,
      contains('Dein Name in der Ansicht'),
    );
    handle.dispose();
  });

  testWidgets('leaving while the create is on its way: the list shows the '
      'sheet once and nothing throws', (tester) async {
    await pump(tester);
    service.gate = Completer<void>();
    await typeName(tester, 'Dr. A');
    await tester.tap(button());
    await tester.pump();
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(ShareCreateScreen), findsNothing);
    expect(find.text('Dein Link ist bereit'), findsNothing);

    service.gate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Deine Freigaben'), findsOneWidget);
    expect(find.text('Dein Link ist bereit'), findsOneWidget);
    expect(find.text('482 913'), findsOneWidget);
    expect(find.byType(SharesScreen, skipOffstage: false), findsOneWidget);
  });

  group('hand-off to the list', () {
    testWidgets('nothing pending: no sheet', (tester) async {
      await pump(tester, openCreate: false);
      expect(find.byType(BottomSheet), findsNothing);
      expect(container.read(justCreatedShareProvider), isNull);
    });

    testWidgets('a pending share opens the sheet once; a rebuild does not '
        'reopen it; the provider is empty', (tester) async {
      await pump(tester, openCreate: false);
      container
          .read(justCreatedShareProvider.notifier)
          .set(const ShareSecret(link: 'https://x.test/s/1', code: '111222'));
      await tester.pumpAndSettle();
      expect(find.text('Dein Link ist bereit'), findsOneWidget);
      expect(find.text('111 222'), findsOneWidget);
      expect(container.read(justCreatedShareProvider), isNull);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);

      container.invalidate(sharesProvider);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(container.read(justCreatedShareProvider), isNull);
    });
  });
}
