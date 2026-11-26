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
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/shares/shares_screen.dart';
import 'package:belly_buddy/services/share_secrets_store.dart';
import 'package:belly_buddy/services/share_service.dart';
import 'package:belly_buddy/widgets/common/bb_async_state.dart';

import '../../helpers/app_host.dart';
import '../../helpers/share_fakes.dart';

void main() {
  final now = DateTime(2026, 11, 26, 12);
  late FakeShareService service;
  late GoRouter router;

  setUpAll(() => initializeDateFormatting('de_DE', null));

  Future<void> pump(
    WidgetTester tester,
    List<DataShare> shares, {
    Map<String, ShareSecret> secrets = const {},
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
    service = FakeShareService(shares);
    final container = ProviderContainer.test(
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        shareServiceProvider.overrideWithValue(service),
        buddyClockProvider.overrideWithValue(() => now),
      ],
    );
    router = GoRouter(
      initialLocation: RoutePaths.shares,
      routes: [
        GoRoute(
          path: RoutePaths.shares,
          builder: (_, _) => const SharesScreen(),
        ),
        ...stubRoutes([RoutePaths.shareCreate]),
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
    expect(find.text('Weitere Freigabe erstellen'), findsNothing);
    await tester.tap(find.text('Freigabe erstellen'));
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
    expect(find.text('Weitere Freigabe erstellen'), findsOneWidget);
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
    await tester.tap(find.text('Weitere Freigabe erstellen'));
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
}

class _Slow extends FakeShareService {
  _Slow(this._answer);
  final Future<List<DataShare>> _answer;
  @override
  Future<List<DataShare>> list() => _answer;
}
