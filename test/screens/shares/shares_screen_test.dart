// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/models/data_share.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/shares_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/shares/shares_screen.dart';
import 'package:belly_buddy/services/share_secrets_store.dart';
import 'package:belly_buddy/services/share_service.dart';
import 'package:belly_buddy/widgets/common/bb_async_state.dart';

import '../../helpers/app_host.dart';
import '../../helpers/share_fakes.dart';
import '../../helpers/purchases_fakes.dart';

void main() {
  final now = DateTime(2026, 11, 26, 12);
  late FakeShareService service;
  late GoRouter router;
  late ProviderContainer container;

  setUpAll(() => initializeDateFormatting('de_DE', null));

  Future<void> pump(
    WidgetTester tester,
    List<DataShare> shares, {
    Map<String, ShareSecret> secrets = const {},
    FakeShareService? using,
    Future<void> Function(ProviderContainer container)? before,
    List<Override> overrides = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final seed = ShareSecretsStore(userId: () => 'u1');
    for (final e in secrets.entries) {
      await seed.save(e.key, e.value);
    }
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    service = using ?? FakeShareService(shares);
    container = ProviderContainer.test(
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        shareServiceProvider.overrideWithValue(service),
        buddyClockProvider.overrideWithValue(() => now),
        ...overrides,
      ],
    );
    if (before != null) await before(container);
    router = GoRouter(
      initialLocation: RoutePaths.shares,
      routes: [
        GoRoute(
          path: RoutePaths.shares,
          builder: (_, _) => const SharesScreen(),
        ),
        ...stubRoutes([
          RoutePaths.shareCreate,
          RoutePaths.dietitianConnect,
          RoutePaths.dietitianShareEdit,
          RoutePaths.plus,
        ]),
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
  }

  testWidgets('empty: explanation and the create button', (tester) async {
    await pump(tester, []);
    expect(find.text('Deine Freigaben'), findsOneWidget);
    expect(
      find.text(
        'Teile dein Tagebuch mit deiner Diätolog:in oder Ärzt:in. Du '
        'entscheidest, was sie sehen, und kannst es jederzeit beenden.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Link erstellen'));
    await tester.pumpAndSettle();
    expect(find.text('page:/shares/new'), findsOneWidget);
  });

  testWidgets('active first, then the others; old inactive ones hidden', (
    tester,
  ) async {
    await pump(tester, [
      testShare(
        id: 'ended',
        period: SharePeriod.days30,
        revokedAt: DateTime(2026, 11, 20),
        createdAt: DateTime(2026, 11, 25),
      ),
      testShare(id: 'active', createdAt: DateTime(2026, 11, 10)),
      testShare(
        id: 'old',
        period: SharePeriod.all,
        expiresAt: DateTime(2026, 8, 1),
        createdAt: DateTime(2026, 6, 1),
      ),
      testShare(
        id: 'recent',
        period: SharePeriod.all,
        photos: true,
        expiresAt: DateTime(2026, 10, 1),
        createdAt: DateTime(2026, 9, 1),
      ),
    ]);

    final active = tester.getTopLeft(find.text('Letzte 14 Tage, ohne Fotos'));
    final ended = tester.getTopLeft(find.text('Letzte 30 Tage, ohne Fotos'));
    final expired = tester.getTopLeft(find.text('Alle Einträge, mit Fotos'));
    expect(active.dy, lessThan(ended.dy));
    expect(ended.dy, lessThan(expired.dy));
    // 'old' expired on 1 Aug, more than 90 days ago.
    expect(find.text('Alle Einträge, ohne Fotos'), findsNothing);
    expect(find.text('Link erstellen'), findsOneWidget);
  });

  testWidgets('the ninety days run from when a share stopped', (tester) async {
    await pump(tester, [
      // Created long ago but ended 10 days ago: shown.
      testShare(
        revokedAt: DateTime(2026, 11, 16),
        createdAt: DateTime(2026, 5, 1),
      ),
    ]);
    expect(find.text('Beendet'), findsOneWidget);
  });

  testWidgets('state words', (tester) async {
    await pump(tester, [
      testShare(id: 'a'),
      testShare(id: 'b', revokedAt: DateTime(2026, 11, 21)),
      testShare(id: 'c', expiresAt: DateTime(2026, 11, 25)),
      testShare(id: 'd', lockedAt: DateTime(2026, 11, 22)),
    ]);
    for (final word in ['Aktiv', 'Beendet', 'Abgelaufen', 'Gesperrt']) {
      expect(find.text(word), findsOneWidget, reason: word);
    }
  });

  testWidgets('created and opened lines', (tester) async {
    await pump(tester, [
      testShare(id: 'a', createdAt: DateTime(2026, 11, 12, 9)),
      testShare(
        id: 'b',
        createdAt: DateTime(2026, 11, 10),
        openCount: 1,
        lastOpenedAt: DateTime(2026, 11, 25, 16, 40),
      ),
      testShare(
        id: 'c',
        createdAt: DateTime(2026, 11, 2),
        openCount: 3,
        lastOpenedAt: DateTime(2026, 11, 24, 8, 5),
      ),
    ]);
    expect(
      find.text('Erstellt am 12. Nov. · noch nicht geöffnet'),
      findsOneWidget,
    );
    expect(
      find.text('Erstellt am 10. Nov. · zuletzt geöffnet 25. Nov., 16:40'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Erstellt am 2. Nov. · zuletzt geöffnet 24. Nov., 08:05 · '
        '3-mal geöffnet',
      ),
      findsOneWidget,
    );
  });

  testWidgets('ended and expired shares have no actions', (tester) async {
    await pump(tester, [
      testShare(id: 'b', revokedAt: DateTime(2026, 11, 21)),
      testShare(id: 'c', expiresAt: DateTime(2026, 11, 25)),
    ]);
    expect(find.text('Freigabe beenden'), findsNothing);
    expect(find.text('Neu erstellen'), findsNothing);
    expect(find.text('Link und Code anzeigen'), findsNothing);
  });

  testWidgets('active without a local secret: hint and „Neu erstellen"', (
    tester,
  ) async {
    await pump(tester, [testShare()]);
    expect(find.text('Auf diesem Gerät nicht gespeichert'), findsOneWidget);
    expect(find.text('Link und Code anzeigen'), findsNothing);
    expect(find.text('Freigabe beenden'), findsOneWidget);

    await tester.tap(find.text('Neu erstellen'));
    await tester.pumpAndSettle();
    expect(find.text('page:/shares/new'), findsOneWidget);
  });

  testWidgets('secret on this device: „Link und Code anzeigen"', (
    tester,
  ) async {
    await pump(
      tester,
      [testShare()],
      secrets: {
        's1': const ShareSecret(
          link: 'https://example.test/s/abc',
          code: '482913',
        ),
      },
    );

    expect(find.text('Auf diesem Gerät nicht gespeichert'), findsNothing);
    expect(find.text('Neu erstellen'), findsNothing);
    await tester.tap(find.text('Link und Code anzeigen'));
    await tester.pumpAndSettle();
    expect(find.text('https://example.test/s/abc'), findsOneWidget);
    expect(find.text('482 913'), findsOneWidget);
  });

  testWidgets('ending: confirm, then the share is ended', (tester) async {
    await pump(tester, [testShare()]);
    await tester.tap(find.text('Freigabe beenden'));
    await tester.pumpAndSettle();

    expect(find.text('Freigabe beenden?'), findsOneWidget);
    expect(
      find.text('Die Berater:in kann dein Tagebuch dann nicht mehr sehen.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Beenden'));
    await tester.pumpAndSettle();

    expect(service.ended, ['s1']);
    expect(find.text('Beendet'), findsOneWidget);
    expect(find.text('Freigabe beenden'), findsNothing);
  });

  testWidgets('ending: „Abbrechen" changes nothing', (tester) async {
    await pump(tester, [testShare()]);
    await tester.tap(find.text('Freigabe beenden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(find.text('Freigabe beenden?'), findsNothing);
    expect(service.ended, isEmpty);
    expect(find.text('Aktiv'), findsOneWidget);
  });

  testWidgets('a failed end says so and leaves the list', (tester) async {
    await pump(tester, [testShare()]);
    service.failEnd = true;
    await tester.tap(find.text('Freigabe beenden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beenden'));
    await tester.pumpAndSettle();

    expect(
      find.text('Beenden hat nicht geklappt. Versuch es später nochmal.'),
      findsOneWidget,
    );
    expect(find.text('Aktiv'), findsOneWidget);
    expect(find.text('Freigabe beenden'), findsOneWidget);
  });

  testWidgets('the bottom button creates another share', (tester) async {
    await pump(tester, [testShare()]);
    await tester.tap(find.text('Link erstellen'));
    await tester.pumpAndSettle();
    expect(find.text('page:/shares/new'), findsOneWidget);
  });

  testWidgets('a failed load shows the error view; retry reloads', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    service = FakeShareService([testShare()])..failList = true;
    final container = ProviderContainer.test(
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        shareServiceProvider.overrideWithValue(service),
        buddyClockProvider.overrideWithValue(() => now),
      ],
    );
    final r = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const SharesScreen())],
    );
    addTearDown(r.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: germanRouterApp(r),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BbErrorState), findsOneWidget);
    service.failList = false;
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();
    expect(find.text('Aktiv'), findsOneWidget);
  });

  testWidgets('an active share shows until when it is valid', (tester) async {
    await pump(tester, [testShare()]);
    expect(find.text('gültig bis 20. Dez.'), findsOneWidget);
  });

  testWidgets('ended shares do not show a valid-until line', (tester) async {
    await pump(tester, [testShare(revokedAt: DateTime(2026, 11, 21))]);
    expect(find.textContaining('gültig bis'), findsNothing);
  });

  group('5 active shares', () {
    final five = [for (var i = 0; i < 5; i++) testShare(id: 's$i')];
    const hint =
        'Du hast schon 5 aktive Links. Beende einen, um einen neuen zu '
        'erstellen.';

    testWidgets('create buttons are disabled and the line says why', (
      tester,
    ) async {
      await pump(tester, five);
      expect(find.text(hint), findsOneWidget);
      await tester.tap(find.text('Link erstellen'));
      await tester.pumpAndSettle();
      expect(find.text('page:/shares/new'), findsNothing);
      // „Neu erstellen" on a tile is disabled too.
      await tester.tap(find.text('Neu erstellen').first);
      await tester.pumpAndSettle();
      expect(find.text('page:/shares/new'), findsNothing);
    });

    testWidgets('4 active: still enabled, no line', (tester) async {
      await pump(tester, five.take(4).toList());
      expect(find.text(hint), findsNothing);
      await tester.tap(find.text('Neu erstellen').first);
      await tester.pumpAndSettle();
      expect(find.text('page:/shares/new'), findsOneWidget);
    });

    testWidgets('ended ones do not count', (tester) async {
      await pump(tester, [
        ...five.take(4),
        testShare(id: 'x', revokedAt: DateTime(2026, 11, 21)),
      ]);
      expect(find.text(hint), findsNothing);
    });
  });

  group('connected dietitians', () {
    const dietitiansFull =
        'Du hast 3 Berater:innen verbunden. Beende eine Verbindung, um eine '
        'neue hinzuzufügen.';

    testWidgets('sections: dietitians above links; empty one hidden', (
      tester,
    ) async {
      await pump(tester, [testShare(), testDietitianShare()]);
      final dietitians = tester.getTopLeft(
        find.text('Verbundene Berater:innen'),
      );
      final links = tester.getTopLeft(find.text('Links'));
      expect(dietitians.dy, lessThan(links.dy));
      expect(find.text('Anna Berger'), findsOneWidget);
      expect(find.text('Letzte 14 Tage, ohne Fotos'), findsOneWidget);
    });

    testWidgets('only links: no dietitian section', (tester) async {
      await pump(tester, [testShare()]);
      expect(find.text('Verbundene Berater:innen'), findsNothing);
      expect(find.text('Links'), findsOneWidget);
    });

    testWidgets('only dietitians: no links section; link tile unused', (
      tester,
    ) async {
      await pump(tester, [testDietitianShare()]);
      expect(find.text('Verbundene Berater:innen'), findsOneWidget);
      expect(find.text('Links'), findsNothing);
      expect(find.text('Auf diesem Gerät nicht gespeichert'), findsNothing);
      expect(find.textContaining('gültig bis'), findsNothing);
    });

    testWidgets('both buttons are shown, also without shares', (tester) async {
      await pump(tester, []);
      expect(find.text('Berater:in verbinden'), findsOneWidget);
      expect(find.text('Link erstellen'), findsOneWidget);
      await tester.tap(find.text('Berater:in verbinden'));
      await tester.pumpAndSettle();
      expect(find.text('page:/shares/connect'), findsOneWidget);
    });

    testWidgets('2 active: connect still enabled', (tester) async {
      await pump(tester, [
        testDietitianShare(id: 'a'),
        testDietitianShare(id: 'b'),
      ]);
      expect(find.text(dietitiansFull), findsNothing);
      await tester.tap(find.text('Berater:in verbinden'));
      await tester.pumpAndSettle();
      expect(find.text('page:/shares/connect'), findsOneWidget);
    });

    testWidgets('3 active: connect disabled, the line says why', (
      tester,
    ) async {
      await pump(tester, [
        for (final id in ['a', 'b', 'c']) testDietitianShare(id: id),
      ]);
      expect(find.text(dietitiansFull), findsOneWidget);
      await tester.tap(find.text('Berater:in verbinden'));
      await tester.pumpAndSettle();
      expect(find.text('page:/shares/connect'), findsNothing);
      // Links are a separate limit.
      await tester.tap(find.text('Link erstellen'));
      await tester.pumpAndSettle();
      expect(find.text('page:/shares/new'), findsOneWidget);
    });

    testWidgets('an ended connection does not count', (tester) async {
      await pump(tester, [
        testDietitianShare(id: 'a'),
        testDietitianShare(id: 'b'),
        testDietitianShare(id: 'c', revokedAt: DateTime(2026, 11, 20)),
      ]);
      expect(find.text(dietitiansFull), findsNothing);
    });

    testWidgets('„Ändern" pushes the edit route with the id', (tester) async {
      await pump(tester, [testDietitianShare(id: 'abc')]);
      await tester.tap(find.text('Ändern'));
      await tester.pumpAndSettle();
      expect(find.text('page:/shares/:id/edit'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/shares/abc/edit',
      );
    });

    testWidgets('„Beenden" asks, then ends the connection', (tester) async {
      await pump(tester, [testDietitianShare(id: 'abc')]);
      await tester.tap(find.text('Beenden'));
      await tester.pumpAndSettle();
      expect(
        find.text('Die Berater:in kann dein Tagebuch dann nicht mehr sehen.'),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Beenden'),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.ended, ['abc']);
      expect(find.text('Beendet'), findsOneWidget);
    });

    testWidgets('a deleted dietitian ends the connection, not counted', (
      tester,
    ) async {
      await pump(tester, [
        testDietitianShare(id: 'a'),
        testDietitianShare(id: 'b'),
        testDietitianShare(id: 'g', dietitianId: null),
      ]);
      expect(find.text('Berater:in (Konto gelöscht)'), findsOneWidget);
      expect(find.text('Beendet'), findsOneWidget);
      expect(find.text(dietitiansFull), findsNothing);
    });

    testWidgets('a deleted dietitian without dates ages out after 90 days', (
      tester,
    ) async {
      await pump(tester, [
        testDietitianShare(
          id: 'old',
          dietitianId: null,
          createdAt: DateTime(2026, 6, 1),
        ),
        testDietitianShare(
          id: 'new',
          dietitianId: null,
          createdAt: DateTime(2026, 11, 1),
        ),
      ]);
      expect(find.text('Berater:in (Konto gelöscht)'), findsOneWidget);
    });

    testWidgets('a paused connection: word, only Beenden', (tester) async {
      await pump(tester, [
        testDietitianShare(
          dietitian: testCard(blockedAt: DateTime(2026, 11, 20)),
        ),
      ]);
      expect(find.text('Pausiert'), findsOneWidget);
      expect(
        find.text('Diese Verbindung ist gerade pausiert.'),
        findsOneWidget,
      );
      expect(find.text('Ändern'), findsNothing);
      expect(find.text('Beenden'), findsOneWidget);
    });

    testWidgets('3 connections with one paused: connect disabled', (
      tester,
    ) async {
      await pump(tester, [
        testDietitianShare(id: 'a'),
        testDietitianShare(id: 'b'),
        testDietitianShare(
          id: 'c',
          dietitian: testCard(blockedAt: DateTime(2026, 11, 20)),
        ),
      ]);
      expect(find.text(dietitiansFull), findsOneWidget);
      await tester.tap(find.text('Berater:in verbinden'));
      await tester.pumpAndSettle();
      expect(find.text('page:/shares/connect'), findsNothing);
    });

    testWidgets('a link a dietitian kept says who keeps it', (tester) async {
      await pump(tester, [
        testShare(
          keeper: testCard(name: 'Berta Huber'),
          keptBy: 'dt2',
        ),
        testShare(id: 's2'),
      ]);
      expect(find.text('Behalten von Berta Huber'), findsOneWidget);
    });
  });

  testWidgets('a failed end reloads the list (ended elsewhere)', (
    tester,
  ) async {
    await pump(tester, [testShare()]);
    final calls = service.listCalls;
    service.failEnd = true;
    service.shares = [testShare(revokedAt: DateTime(2026, 11, 25))];
    await tester.tap(find.text('Freigabe beenden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beenden'));
    await tester.pumpAndSettle();
    expect(service.listCalls, greaterThan(calls));
    expect(find.text('Beendet'), findsOneWidget);
  });

  testWidgets('opening the screen refreshes a list loaded earlier', (
    tester,
  ) async {
    await pump(
      tester,
      [testShare()],
      before: (c) async {
        await c.read(sharesProvider.future);
        service.shares = [
          testShare(openCount: 1, lastOpenedAt: DateTime(2026, 11, 25, 16, 40)),
        ];
      },
    );
    expect(
      find.textContaining('zuletzt geöffnet 25. Nov., 16:40'),
      findsOneWidget,
    );
  });

  testWidgets('pull to refresh loads again', (tester) async {
    await pump(tester, [testShare()]);
    service.shares = [
      testShare(openCount: 2, lastOpenedAt: DateTime(2026, 11, 26, 8, 0)),
    ];
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 400),
      800,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('2-mal geöffnet'), findsOneWidget);
  });

  testWidgets('an end that fails after leaving the list throws nothing', (
    tester,
  ) async {
    final slow = _SlowEnd([testShare()]);
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer.test(
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        shareServiceProvider.overrideWithValue(slow),
        buddyClockProvider.overrideWithValue(() => now),
      ],
    );
    final r = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Ich')),
          routes: [
            GoRoute(path: 'shares', builder: (_, _) => const SharesScreen()),
          ],
        ),
      ],
    );
    addTearDown(r.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: germanRouterApp(r)),
    );
    unawaited(r.push('/shares'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Freigabe beenden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beenden'));
    await tester.pump();
    // The list is left before the answer comes.
    r.pop();
    await tester.pumpAndSettle();
    expect(find.byType(SharesScreen), findsNothing);

    slow.gate.completeError(const ShareException());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unreadable stored secret still lets the share be ended', (
    tester,
  ) async {
    await pump(
      tester,
      [testShare()],
      overrides: [
        shareSecretProvider.overrideWith((ref, id) => throw Exception('io')),
      ],
    );
    expect(find.text('Freigabe beenden'), findsOneWidget);
    expect(find.text('Neu erstellen'), findsOneWidget);
  });

  testWidgets('the first open loads the list once', (tester) async {
    await pump(tester, [testShare()]);
    expect(service.listCalls, 1);
  });

  const refreshFailed =
      'Aktualisieren hat nicht geklappt. Versuch es später nochmal.';

  testWidgets('a failed pull to refresh says so and keeps the list', (
    tester,
  ) async {
    await pump(tester, [testShare()]);
    service.failList = true;
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 400),
      800,
    );
    await tester.pumpAndSettle();
    expect(find.text(refreshFailed), findsOneWidget);
    expect(find.text('Aktiv'), findsOneWidget);
  });

  testWidgets('a failed refresh on opening says so and keeps the list', (
    tester,
  ) async {
    await pump(
      tester,
      [testShare()],
      before: (c) async {
        await c.read(sharesProvider.future);
        service.failList = true;
      },
    );
    expect(find.text(refreshFailed), findsOneWidget);
    expect(find.text('Aktiv'), findsOneWidget);
  });

  testWidgets('refreshing keeps the list, no spinner', (tester) async {
    final slow = _SlowSecond([testShare()]);
    await pump(tester, [], using: slow);
    expect(find.text('Aktiv'), findsOneWidget);
    // The refresh from opening is still pending, or was answered: pull again.
    slow.gate = Completer<void>();
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 400),
      800,
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(BbLoadingState), findsNothing);
    expect(find.text('Aktiv'), findsOneWidget);
    slow.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a hand-off made before the list mounts shows the sheet once', (
    tester,
  ) async {
    await pump(
      tester,
      [testShare()],
      before: (c) async => c
          .read(justCreatedShareProvider.notifier)
          .set(
            const ShareSecret(
              link: 'https://example.test/s/zzz',
              code: '123456',
            ),
          ),
    );
    expect(find.text('Dein Link ist bereit'), findsOneWidget);
    expect(find.text('https://example.test/s/zzz'), findsOneWidget);
    expect(container.read(justCreatedShareProvider), isNull);
    // Closing it does not bring it back.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Dein Link ist bereit'), findsNothing);
  });

  testWidgets('while loading, a loading view shows', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final never = Completer<List<DataShare>>();
    final container = ProviderContainer.test(
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        shareServiceProvider.overrideWithValue(_Slow(never.future)),
        buddyClockProvider.overrideWithValue(() => now),
      ],
    );
    final r = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const SharesScreen())],
    );
    addTearDown(r.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: germanRouterApp(r),
      ),
    );
    await tester.pump();
    expect(find.byType(BbLoadingState), findsOneWidget);
  });

  group('Plus locked', () {
    final locked = plusLockedOverrides;

    testWidgets('existing shares stay listed', (tester) async {
      await pump(tester, [
        testShare(),
        testDietitianShare(id: 'd1'),
      ], overrides: locked);
      expect(find.text('Verbundene Berater:innen'), findsOneWidget);
      expect(find.text('Links'), findsOneWidget);
      expect(find.text('Freigabe beenden'), findsOneWidget);
    });

    testWidgets('ending a link still works', (tester) async {
      await pump(tester, [testShare()], overrides: locked);
      await tester.tap(find.text('Freigabe beenden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beenden'));
      await tester.pumpAndSettle();

      expect(service.ended, ['s1']);
      expect(find.text('page:/plus'), findsNothing);
    });

    testWidgets('ending a connection still works', (tester) async {
      await pump(tester, [testDietitianShare(id: 'abc')], overrides: locked);
      await tester.tap(find.text('Beenden'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Beenden'),
        ),
      );
      await tester.pumpAndSettle();

      expect(service.ended, ['abc']);
      expect(find.text('page:/plus'), findsNothing);
    });

    testWidgets('„Link erstellen" opens /plus', (tester) async {
      await pump(tester, [], overrides: locked);
      await tester.tap(find.text('Link erstellen'));
      await tester.pumpAndSettle();
      expect(find.text('page:/plus'), findsOneWidget);
      expect(find.text('page:/shares/new'), findsNothing);
    });

    testWidgets('„Berater:in verbinden" opens /plus', (tester) async {
      await pump(tester, [], overrides: locked);
      await tester.tap(find.text('Berater:in verbinden'));
      await tester.pumpAndSettle();
      expect(find.text('page:/plus'), findsOneWidget);
      expect(find.text('page:/shares/connect'), findsNothing);
    });

    testWidgets('„Neu erstellen" opens /plus', (tester) async {
      await pump(tester, [testShare()], overrides: locked);
      await tester.tap(find.text('Neu erstellen'));
      await tester.pumpAndSettle();
      expect(find.text('page:/plus'), findsOneWidget);
    });

    testWidgets('„Ändern" still opens the edit screen', (tester) async {
      await pump(tester, [testDietitianShare(id: 'abc')], overrides: locked);
      await tester.tap(find.text('Ändern'));
      await tester.pumpAndSettle();
      expect(find.text('page:/shares/:id/edit'), findsOneWidget);
    });

    testWidgets('open: the buttons create as before', (tester) async {
      await pump(tester, [], overrides: plusOpenOverrides);
      await tester.tap(find.text('Berater:in verbinden'));
      await tester.pumpAndSettle();
      expect(find.text('page:/shares/connect'), findsOneWidget);
    });
  });
}

class _Slow extends FakeShareService {
  _Slow(this._answer);
  final Future<List<DataShare>> _answer;
  @override
  Future<List<DataShare>> list() => _answer;
}

/// Answers at once, until [gate] is set: then the next list waits for it.
class _SlowSecond extends FakeShareService {
  _SlowSecond(super.shares);
  Completer<void>? gate;
  @override
  Future<List<DataShare>> list() async {
    final g = gate;
    if (g != null) await g.future;
    return super.list();
  }
}

/// An end that waits for [gate], which decides how it ends.
class _SlowEnd extends FakeShareService {
  _SlowEnd(super.shares);
  final gate = Completer<void>();
  @override
  Future<void> end(String id) => gate.future;
}
