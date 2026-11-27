import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/plus_status.dart';
import 'package:belly_buddy/providers/plus_provider.dart';
import 'package:belly_buddy/screens/plus/plus_screen.dart';
import 'package:belly_buddy/services/app_version_service.dart';
import 'package:belly_buddy/services/edge_function_service.dart';
import 'package:belly_buddy/services/plus/plus_copy.dart';
import 'package:belly_buddy/services/purchases/purchases_gateway.dart';

import '../../helpers/app_host.dart';
import '../../helpers/mocks.dart';
import '../../helpers/purchases_fakes.dart';
import '../../helpers/riverpod_helpers.dart';

class _FakeAppVersionService extends AppVersionService {
  @override
  Future<String> packageName() async => 'at.bellybuddy.app';
}

void main() {
  late FakePurchasesGateway gateway;
  late MockEdgeFunctionService edge;
  late List<Uri> opened;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    gateway = FakePurchasesGateway(offerAnswer: testPlusOffer());
    edge = MockEdgeFunctionService();
    when(
      () => edge.invoke(any(), body: any(named: 'body')),
    ).thenAnswer((_) async => {'plus': true, 'expires_at': null});
    opened = [];
  });

  tearDown(() => gateway.dispose());

  Future<bool> record(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) {
    opened.add(url);
    return Future.value(true);
  }

  /// Home below, the paywall pushed on top.
  Future<GoRouter> pump(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('page:home')),
        ),
        GoRoute(
          path: '/plus',
          builder: (_, _) => PlusScreen(openUrl: record),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          SwitchableUserId().override,
          paywallEnabledProvider.overrideWithValue(true),
          purchasesGatewayProvider.overrideWithValue(gateway),
          edgeFunctionServiceProvider.overrideWithValue(edge),
          appVersionServiceProvider.overrideWithValue(_FakeAppVersionService()),
        ],
        child: germanRouterApp(router),
      ),
    );
    unawaited(router.push('/plus'));
    await tester.pumpAndSettle();
    expect(find.byType(PlusScreen), findsOneWidget);
    return router;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
  }

  testWidgets('shows the title, the benefits and the free line', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(PlusCopy.title), findsOneWidget);
    expect(find.text(PlusCopy.intro), findsOneWidget);
    for (final b in PlusCopy.benefits) {
      expect(find.text(b), findsOneWidget);
    }
    expect(find.text(PlusCopy.free), findsOneWidget);
    expect(find.byKey(PlusScreen.closeKey), findsOneWidget);
  });

  testWidgets(
    'eligible offer: "14 Tage gratis, danach 6,90 € pro Monat" from the fake offer',
    (tester) async {
      await pump(tester);
      expect(
        find.text('14 Tage gratis, danach 6,90 € pro Monat'),
        findsOneWidget,
      );
      expect(find.text('14 Tage gratis testen'), findsOneWidget);
    },
  );

  testWidgets('not eligible: "6,90 € pro Monat" and "Plus abonnieren"', (
    tester,
  ) async {
    gateway.offerAnswer = testPlusOffer(trialDays: null);
    await pump(tester);
    expect(find.text('6,90 € pro Monat'), findsOneWidget);
    expect(find.text('Plus abonnieren'), findsOneWidget);
  });

  testWidgets(
    'no offer: unavailable line, no buy button, restore still there',
    (tester) async {
      gateway.offerAnswer = null;
      await pump(tester);
      expect(
        find.text(
          'Belly Buddy Plus ist gerade nicht verfügbar. '
          'Versuch es später nochmal.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(PlusScreen.buyKey), findsNothing);
      expect(find.byKey(PlusScreen.restoreKey), findsOneWidget);
    },
  );

  testWidgets('no SDK key: unavailable line, no buy button', (tester) async {
    gateway.available = false;
    await pump(tester);
    expect(find.text(PlusCopy.unavailable), findsOneWidget);
    expect(find.byKey(PlusScreen.buyKey), findsNothing);
    expect(gateway.callsNamed('offer'), isEmpty);
  });

  testWidgets('an offer that fails to load: unavailable line', (tester) async {
    gateway.offerError = Exception('network');
    await pump(tester);
    expect(find.text(PlusCopy.unavailable), findsOneWidget);
    expect(find.byKey(PlusScreen.buyKey), findsNothing);
  });

  testWidgets('iOS shows termsIos; terms and privacy links open their URLs', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(PlusCopy.termsIos), findsOneWidget);
    expect(find.text(PlusCopy.termsAndroid), findsNothing);
    expect(PlusCopy.termsIos, contains('Apple-ID'));

    await tapVisible(tester, find.byKey(PlusScreen.termsKey));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(PlusScreen.privacyKey));
    await tester.pumpAndSettle();
    expect(opened, [
      Uri.parse(AppConstants.termsUrl),
      Uri.parse(AppConstants.privacyPolicyUrl),
    ]);
    expect(find.text(PlusCopy.terms), findsOneWidget);
    expect(find.text(PlusCopy.privacy), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android shows termsAndroid', (tester) async {
    await pump(tester);
    expect(find.text(PlusCopy.termsAndroid), findsOneWidget);
    expect(find.text(PlusCopy.termsIos), findsNothing);
    expect(PlusCopy.termsAndroid, contains('Google-Play-Konto'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('purchase done: closes and shows "Willkommen bei Belly Buddy '
      'Plus!"', (tester) async {
    await pump(tester);
    await tapVisible(tester, find.byKey(PlusScreen.buyKey));
    await tester.pumpAndSettle();
    expect(gateway.callsNamed('purchase'), ['purchase:6,90 €']);
    verify(() => edge.invoke('plus-sync')).called(1);
    expect(find.byType(PlusScreen), findsNothing);
    expect(find.text('page:home'), findsOneWidget);
    expect(find.text('Willkommen bei Belly Buddy Plus!'), findsOneWidget);
  });

  testWidgets('purchase done but not granted: stays with the pending line, '
      'no welcome', (tester) async {
    gateway.purchaseAnswer = const PurchaseDone(PlusStatus.none);
    await pump(tester);
    await tapVisible(tester, find.byKey(PlusScreen.buyKey));
    await tester.pumpAndSettle();
    expect(gateway.callsNamed('purchase'), ['purchase:6,90 €']);
    expect(find.byType(PlusScreen), findsOneWidget);
    expect(find.text(PlusCopy.pending), findsOneWidget);
    expect(find.text('Willkommen bei Belly Buddy Plus!'), findsNothing);
  });

  testWidgets('double tap on buy runs one purchase', (tester) async {
    await pump(tester);
    final sheet = gateway.holdNextPurchase();
    final buy = find.byKey(PlusScreen.buyKey);
    await tester.ensureVisible(buy);
    await tester.pumpAndSettle();
    await tester.tap(buy);
    await tester.tap(buy, warnIfMissed: false);
    await tester.pump();
    await tester.tap(buy, warnIfMissed: false);
    await tester.pump();
    expect(gateway.callsNamed('purchase'), hasLength(1));
    sheet.complete(const PurchaseCancelled());
    await tester.pumpAndSettle();
    expect(gateway.callsNamed('purchase'), hasLength(1));
  });

  testWidgets('the close button works while a purchase is in flight', (
    tester,
  ) async {
    await pump(tester);
    final sheet = gateway.holdNextPurchase();
    await tapVisible(tester, find.byKey(PlusScreen.buyKey));
    await tester.pump();
    expect(find.byKey(PlusScreen.closeKey).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(PlusScreen.closeKey));
    await tester.pumpAndSettle();
    expect(find.byType(PlusScreen), findsNothing);
    sheet.complete(const PurchaseDone(PlusStatus(state: PlusState.trial)));
    await tester.pumpAndSettle();
    expect(find.text('page:home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled: stays, no SnackBar', (tester) async {
    gateway.purchaseAnswer = const PurchaseCancelled();
    await pump(tester);
    await tapVisible(tester, find.byKey(PlusScreen.buyKey));
    await tester.pumpAndSettle();
    expect(find.byType(PlusScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    // The button is usable again.
    await tapVisible(tester, find.byKey(PlusScreen.buyKey));
    await tester.pumpAndSettle();
    expect(gateway.callsNamed('purchase'), hasLength(2));
  });

  testWidgets('pending: "Dein Kauf wartet noch auf Bestätigung."', (
    tester,
  ) async {
    gateway.purchaseAnswer = const PurchasePending();
    await pump(tester);
    await tapVisible(tester, find.byKey(PlusScreen.buyKey));
    await tester.pumpAndSettle();
    expect(find.byType(PlusScreen), findsOneWidget);
    expect(find.text('Dein Kauf wartet noch auf Bestätigung.'), findsOneWidget);
  });

  testWidgets('failed: "Der Kauf hat nicht geklappt. Du wurdest nicht '
      'belastet."', (tester) async {
    gateway.purchaseAnswer = const PurchaseFailed();
    await pump(tester);
    await tapVisible(tester, find.byKey(PlusScreen.buyKey));
    await tester.pumpAndSettle();
    expect(find.byType(PlusScreen), findsOneWidget);
    expect(
      find.text('Der Kauf hat nicht geklappt. Du wurdest nicht belastet.'),
      findsOneWidget,
    );
  });

  testWidgets('restore with nothing found: "Wir haben kein Abo gefunden."', (
    tester,
  ) async {
    await pump(tester);
    await tapVisible(tester, find.byKey(PlusScreen.restoreKey));
    await tester.pumpAndSettle();
    expect(gateway.callsNamed('restore'), hasLength(1));
    expect(find.byType(PlusScreen), findsOneWidget);
    expect(find.text('Wir haben kein Abo gefunden.'), findsOneWidget);
    expect(find.text(PlusCopy.restore), findsOneWidget);
  });

  testWidgets('restore found: closes with the welcome', (tester) async {
    gateway.restoreAnswer = const PurchaseDone(
      PlusStatus(state: PlusState.active),
    );
    await pump(tester);
    await tapVisible(tester, find.byKey(PlusScreen.restoreKey));
    await tester.pumpAndSettle();
    expect(find.byType(PlusScreen), findsNothing);
    expect(find.text(PlusCopy.welcome), findsOneWidget);
  });

  testWidgets('restore failed: restoreFailed line', (tester) async {
    gateway.restoreAnswer = const PurchaseFailed();
    await pump(tester);
    await tapVisible(tester, find.byKey(PlusScreen.restoreKey));
    await tester.pumpAndSettle();
    expect(find.byType(PlusScreen), findsOneWidget);
    expect(
      find.text(
        'Wiederherstellen hat nicht geklappt. Versuch es später nochmal.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('with Plus: status line and "Abo verwalten", no buy button', (
    tester,
  ) async {
    gateway.statusAnswer = PlusStatus(
      state: PlusState.active,
      expiresAt: DateTime.utc(2026, 12, 10, 12),
      willRenew: true,
      managementUrl: 'https://apps.apple.com/account/subscriptions?x=1',
    );
    await pump(tester);
    expect(find.text('Aktiv · verlängert sich am 10.12.'), findsOneWidget);
    expect(find.byKey(PlusScreen.buyKey), findsNothing);
    expect(find.byKey(PlusScreen.restoreKey), findsOneWidget);
    expect(find.text('Abo verwalten'), findsOneWidget);
    await tapVisible(tester, find.byKey(PlusScreen.manageKey));
    await tester.pumpAndSettle();
    expect(opened, [
      Uri.parse('https://apps.apple.com/account/subscriptions?x=1'),
    ]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'with Plus, no management URL on iOS: the App Store subscriptions page',
    (tester) async {
      gateway.statusAnswer = const PlusStatus(state: PlusState.trial);
      await pump(tester);
      await tapVisible(tester, find.byKey(PlusScreen.manageKey));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse(AppConstants.appleSubscriptionsUrl)]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'with Plus, no management URL on Android: the Play subscriptions page',
    (tester) async {
      gateway.statusAnswer = const PlusStatus(state: PlusState.trial);
      await pump(tester);
      await tapVisible(tester, find.byKey(PlusScreen.manageKey));
      await tester.pumpAndSettle();
      expect(opened, [
        Uri.parse(
          AppConstants.playSubscriptionsUrl(
            AppConstants.playPlusProductId,
            'at.bellybuddy.app',
          ),
        ),
      ]);
      expect(
        opened.single.toString(),
        'https://play.google.com/store/account/subscriptions'
        '?sku=bellybuddy_plus&package=at.bellybuddy.app',
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('lapsed: the buy button again', (tester) async {
    gateway.statusAnswer = const PlusStatus(state: PlusState.lapsed);
    await pump(tester);
    expect(find.byKey(PlusScreen.buyKey), findsOneWidget);
    expect(find.byKey(PlusScreen.manageKey), findsNothing);
  });

  testWidgets('close goes back', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(PlusScreen.closeKey));
    await tester.pumpAndSettle();
    expect(find.text('page:home'), findsOneWidget);
  });

  group('PlusCopy', () {
    final at = DateTime.utc(2026, 12, 10, 12);

    test('priceLine and buyLabel come from the offer', () {
      expect(
        PlusCopy.priceLine('6,90 €', 14),
        '14 Tage gratis, danach 6,90 € pro Monat',
      );
      expect(PlusCopy.priceLine('6,90 €', null), '6,90 € pro Monat');
      expect(PlusCopy.buyLabel(14), '14 Tage gratis testen');
      expect(PlusCopy.buyLabel(null), 'Plus abonnieren');
    });

    test('PlusCopy.statusLine covers trial, trial ending, active, active '
        'ending, billing issue, lapsed, none', () {
      expect(
        PlusCopy.statusLine(PlusStatus.none),
        'Alle Funktionen freischalten',
      );
      expect(
        PlusCopy.statusLine(
          PlusStatus(state: PlusState.trial, expiresAt: at, willRenew: true),
        ),
        'Gratis-Test bis 10.12.',
      );
      expect(
        PlusCopy.statusLine(PlusStatus(state: PlusState.trial, expiresAt: at)),
        'Gratis-Test endet am 10.12.',
      );
      expect(
        PlusCopy.statusLine(
          PlusStatus(state: PlusState.active, expiresAt: at, willRenew: true),
        ),
        'Aktiv · verlängert sich am 10.12.',
      );
      expect(
        PlusCopy.statusLine(PlusStatus(state: PlusState.active, expiresAt: at)),
        'Aktiv bis 10.12.',
      );
      expect(
        PlusCopy.statusLine(
          PlusStatus(
            state: PlusState.active,
            expiresAt: at,
            willRenew: true,
            billingIssue: true,
          ),
        ),
        'Zahlung offen – bitte im Store prüfen',
      );
      expect(
        PlusCopy.statusLine(const PlusStatus(state: PlusState.lapsed)),
        'Abgelaufen · Wieder abonnieren',
      );
      expect(
        PlusCopy.statusLine(
          PlusStatus(
            state: PlusState.active,
            expiresAt: DateTime.utc(2027, 3, 5, 12),
            willRenew: true,
          ),
        ),
        'Aktiv · verlängert sich am 5.3.',
      );
    });

    test('the fixed strings', () {
      expect(PlusCopy.restore, 'Käufe wiederherstellen');
      expect(PlusCopy.terms, 'Nutzungsbedingungen');
      expect(PlusCopy.privacy, 'Datenschutz');
      expect(PlusCopy.manage, 'Abo verwalten');
      expect(PlusCopy.benefits, hasLength(5));
    });
  });
}
