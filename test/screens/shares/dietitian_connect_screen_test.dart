// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/models/data_share.dart';
import 'package:belly_buddy/models/dietitian_card.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/plus_provider.dart';
import 'package:belly_buddy/providers/share_launcher_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/screens/shares/dietitian_connect_screen.dart';
import 'package:belly_buddy/screens/shares/shares_screen.dart';
import 'package:belly_buddy/screens/shares/widgets/practice_code_scanner.dart';
import 'package:belly_buddy/services/share_secrets_store.dart';
import 'package:belly_buddy/services/share_service.dart';

import '../../helpers/app_host.dart';
import '../../helpers/share_fakes.dart';

const _notFound = 'Diesen Code gibt es nicht. Bitte prüfe ihn.';
const _limit =
    'Du hast 3 Berater:innen verbunden. Beende eine Verbindung, um eine neue '
    'hinzuzufügen.';

class _Service extends FakeShareService {
  _Service([super.shares]);

  final List<String> lookedUp = [];
  final List<(String, DietitianShareTerms)> connected = [];
  Object? lookupFails;
  Object? connectFails;

  @override
  Future<DietitianCard> lookup(String code) async {
    lookedUp.add(code);
    if (lookupFails != null) throw lookupFails!;
    return testCard();
  }

  @override
  Future<String> connect(String code, DietitianShareTerms terms) async {
    if (connectFails != null) throw connectFails!;
    connected.add((code, terms));
    return super.connect(code, terms);
  }
}

void main() {
  late _Service service;
  late GoRouter router;
  final scans = <String?>[];

  setUpAll(() => initializeDateFormatting('de_DE', null));

  Future<void> pump(
    WidgetTester tester, {
    List<DataShare> shares = const [],
    String? savedName,
    bool paywallOn = true,
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
    service = _Service(shares);
    scans.clear();
    final container = ProviderContainer.test(
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        paywallEnabledProvider.overrideWithValue(paywallOn),
        shareServiceProvider.overrideWithValue(service),
        buddyClockProvider.overrideWithValue(() => DateTime(2026, 11, 26, 12)),
        shareLauncherProvider.overrideWithValue((_, _) async {}),
        practiceCodeScanProvider.overrideWithValue(
          (_) async => scans.isEmpty ? null : scans.removeAt(0),
        ),
      ],
    );
    router = GoRouter(
      initialLocation: RoutePaths.shares,
      routes: [
        GoRoute(
          path: RoutePaths.shares,
          builder: (_, _) => const SharesScreen(),
          routes: [
            GoRoute(
              path: 'connect',
              builder: (_, _) => const DietitianConnectScreen(),
            ),
          ],
        ),
        GoRoute(
          path: RoutePaths.plus,
          builder: (_, _) => const Scaffold(body: Text('page:/plus')),
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
    unawaited(router.push(RoutePaths.dietitianConnect));
    await tester.pumpAndSettle();
  }

  Finder codeField() => find.widgetWithText(TextField, 'Praxis-Code');

  Future<void> lookUp(WidgetTester tester, String code) async {
    await tester.enterText(codeField(), code);
    await tester.pump();
    await tester.tap(find.text('Code suchen'));
    await tester.pumpAndSettle();
  }

  bool switchOn(WidgetTester tester, String label) => tester
      .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, label))
      .value;

  bool chipSelected(WidgetTester tester, String label) => tester
      .widget<FilterChip>(find.widgetWithText(FilterChip, label))
      .selected;

  Finder submit() => find.widgetWithText(ElevatedButton, 'Freigeben');

  testWidgets('step 1: the field, its hint and the two buttons', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Berater:in verbinden'), findsOneWidget);
    expect(codeField(), findsOneWidget);
    expect(find.text('z. B. BERGER-7K2'), findsOneWidget);
    expect(find.text('Code suchen'), findsOneWidget);
    expect(find.text('QR-Code scannen'), findsOneWidget);
    expect(find.text(_limit), findsNothing);
  });

  testWidgets('a typed lower-case code with a space is sent normalized and '
      'shows the card', (tester) async {
    await pump(tester);
    await lookUp(tester, 'berger 7k2');
    expect(service.lookedUp, ['BERGER-7K2']);
    expect(find.text('Gefunden'), findsOneWidget);
    expect(find.text('Anna Berger'), findsOneWidget);
    expect(
      find.text('Diätolog:in (eigene Angabe) · Praxis Berger, Innsbruck'),
      findsOneWidget,
    );
    expect(codeField(), findsNothing);
  });

  testWidgets('a code without the dash finds the card too', (tester) async {
    await pump(tester);
    await lookUp(tester, 'Berger7K2');
    expect(service.lookedUp, ['BERGER-7K2']);
    expect(find.text('Gefunden'), findsOneWidget);
  });

  testWidgets('an unknown code shows core’s 404 text under the field', (
    tester,
  ) async {
    await pump(tester);
    service.lookupFails = const ShareException(status: 404, message: _notFound);
    await lookUp(tester, 'BERGER-7K3');
    expect(find.text(_notFound), findsOneWidget);
    expect(find.text('Gefunden'), findsNothing);
    expect(codeField(), findsOneWidget);
  });

  testWidgets('a 429 shows core’s text', (tester) async {
    await pump(tester);
    service.lookupFails = const ShareException(
      status: 429,
      message: 'Zu viele Versuche. Bitte warte kurz.',
    );
    await lookUp(tester, 'BERGER-7K3');
    expect(find.text('Zu viele Versuche. Bitte warte kurz.'), findsOneWidget);
  });

  testWidgets('a text that cannot be a code is not sent', (tester) async {
    await pump(tester);
    await lookUp(tester, 'hallo');
    expect(service.lookedUp, isEmpty);
    expect(find.text(_notFound), findsOneWidget);
  });

  testWidgets('the keyboard search key on an empty field does nothing', (
    tester,
  ) async {
    await pump(tester);
    await tester.showKeyboard(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(service.lookedUp, isEmpty);
    expect(find.text(_notFound), findsNothing);
  });

  testWidgets('the scanner result fills the field and looks it up', (
    tester,
  ) async {
    await pump(tester);
    scans.add('BERGER-7K2');
    await tester.tap(find.text('QR-Code scannen'));
    await tester.pumpAndSettle();
    expect(service.lookedUp, ['BERGER-7K2']);
    expect(find.text('Gefunden'), findsOneWidget);
  });

  testWidgets('a closed scanner changes nothing', (tester) async {
    await pump(tester);
    await tester.tap(find.text('QR-Code scannen'));
    await tester.pumpAndSettle();
    expect(service.lookedUp, isEmpty);
    expect(codeField(), findsOneWidget);
  });

  testWidgets('step 2 defaults: photos off, „Bis ich es beende", the name of '
      'the last share, the heading and the sentence', (tester) async {
    await pump(tester, savedName: 'Maria');
    await lookUp(tester, 'BERGER-7K2');
    expect(find.text('Das sieht Anna Berger'), findsOneWidget);
    expect(find.text('Wie lange?'), findsOneWidget);
    expect(chipSelected(tester, 'Bis ich es beende'), isTrue);
    expect(chipSelected(tester, '90 Tage'), isFalse);
    expect(switchOn(tester, 'Fotos der Mahlzeiten'), isFalse);
    for (final l in [
      'Mahlzeiten und Zutaten',
      'Getränke',
      'Bauchgefühl und Symptome',
      'Klo-Einträge',
      'Muster und Unverträglichkeiten',
    ]) {
      expect(switchOn(tester, l), isTrue, reason: l);
    }
    expect(find.text('Maria'), findsOneWidget);
    expect(
      find.text(
        'Du gibst Gesundheitsdaten frei. Du kannst das jederzeit unter '
        '„Deine Freigaben" beenden.',
      ),
      findsOneWidget,
    );
    expect(tester.widget<ElevatedButton>(submit()).onPressed, isNotNull);
  });

  testWidgets('Freigeben sends code and terms, then the list shows the '
      'snackbar', (tester) async {
    await pump(tester, savedName: 'Maria');
    await lookUp(tester, 'berger-7k2');
    await tester.tap(find.text('90 Tage'));
    await tester.tap(find.text('Alles'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Klo-Einträge'));
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Fotos der Mahlzeiten'),
    );
    await tester.pump();
    await tester.tap(submit());
    await tester.pumpAndSettle();

    final (code, t) = service.connected.single;
    expect(code, 'BERGER-7K2');
    expect(t.displayName, 'Maria');
    expect(t.period, SharePeriod.all);
    expect(t.duration, ShareDuration.days90);
    expect(
      [t.meals, t.drinks, t.gut, t.toilet, t.patterns, t.photos],
      [true, true, true, false, true, true],
    );
    expect(find.byType(DietitianConnectScreen), findsNothing);
    expect(find.text('Deine Freigaben'), findsOneWidget);
    expect(find.text('Anna Berger ist verbunden.'), findsOneWidget);
  });

  testWidgets('the default duration is sent as open', (tester) async {
    await pump(tester, savedName: 'Maria');
    await lookUp(tester, 'BERGER-7K2');
    await tester.tap(submit());
    await tester.pumpAndSettle();
    expect(service.connected.single.$2.duration, ShareDuration.open);
    expect(service.connected.single.$2.photos, isFalse);
  });

  testWidgets('Freigeben needs a name', (tester) async {
    await pump(tester);
    await lookUp(tester, 'BERGER-7K2');
    expect(tester.widget<ElevatedButton>(submit()).onPressed, isNull);
  });

  for (final (status, message) in [
    (
      409,
      'Du hast 3 Berater:innen verbunden. Beende eine Verbindung, um eine '
          'neue hinzuzufügen.',
    ),
    (409, 'Du bist mit dieser Berater:in schon verbunden.'),
    (409, 'Das ist dein eigener Praxis-Code.'),
    (403, 'Bitte stimme zuerst der Verarbeitung deiner Gesundheitsdaten zu.'),
  ]) {
    testWidgets('a $status shows core’s text and keeps the form: $message', (
      tester,
    ) async {
      await pump(tester, savedName: 'Maria');
      await lookUp(tester, 'BERGER-7K2');
      await tester.tap(find.text('90 Tage'));
      await tester.tap(find.widgetWithText(SwitchListTile, 'Getränke'));
      await tester.pump();
      service.connectFails = ShareException(status: status, message: message);
      await tester.tap(submit());
      await tester.pumpAndSettle();
      expect(find.text(message), findsWidgets);
      expect(find.byType(DietitianConnectScreen), findsOneWidget);
      expect(find.text('Gefunden'), findsOneWidget);
      expect(chipSelected(tester, '90 Tage'), isTrue);
      expect(switchOn(tester, 'Getränke'), isFalse);
      expect(find.text('Maria'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(submit()).onPressed, isNotNull);
    });
  }

  testWidgets('a 404 on Freigeben (the code went away since the lookup) '
      'returns to step 1 with core’s text under the field', (tester) async {
    const gone = 'Diesen Code gibt es nicht mehr.';
    await pump(tester, savedName: 'Maria');
    await lookUp(tester, 'BERGER-7K2');
    service.connectFails = const ShareException(status: 404, message: gone);
    await tester.tap(submit());
    await tester.pumpAndSettle();

    expect(find.byType(DietitianConnectScreen), findsOneWidget);
    expect(find.text('Gefunden'), findsNothing);
    expect(codeField(), findsOneWidget);
    final field = tester.widget<TextField>(codeField());
    expect(field.decoration?.errorText, gone);
    expect(field.controller?.text, 'BERGER-7K2');
    expect(find.byType(SnackBar), findsNothing);
  });

  // Connecting is free (decision 16): a 402 plus_required is no longer
  // expected and is handled like any other error.
  for (final paywallOn in [true, false]) {
    testWidgets('a 402 plus_required keeps the form with core\'s text, no '
        'paywall (switch ${paywallOn ? 'on' : 'off'})', (tester) async {
      await pump(tester, savedName: 'Maria', paywallOn: paywallOn);
      await lookUp(tester, 'BERGER-7K2');
      service.connectFails = const ShareException(
        status: 402,
        message: 'Dafür brauchst du Belly Buddy Plus.',
        code: 'plus_required',
      );
      await tester.tap(submit());
      await tester.pumpAndSettle();

      expect(find.text('page:/plus'), findsNothing);
      expect(find.byType(DietitianConnectScreen), findsOneWidget);
      expect(find.text('Gefunden'), findsOneWidget);
      expect(find.text('Dafür brauchst du Belly Buddy Plus.'), findsOneWidget);
    });
  }

  testWidgets('a 402 without the code keeps the form with the usual text', (
    tester,
  ) async {
    await pump(tester, savedName: 'Maria');
    await lookUp(tester, 'BERGER-7K2');
    service.connectFails = const ShareException(status: 402);
    await tester.tap(submit());
    await tester.pumpAndSettle();

    expect(find.text('page:/plus'), findsNothing);
    expect(find.byType(DietitianConnectScreen), findsOneWidget);
    expect(find.text('Gefunden'), findsOneWidget);
    expect(
      find.text('Das hat nicht geklappt. Versuch es später nochmal.'),
      findsOneWidget,
    );
  });

  testWidgets('a failure without a message shows the usual text', (
    tester,
  ) async {
    await pump(tester, savedName: 'Maria');
    await lookUp(tester, 'BERGER-7K2');
    service.connectFails = Exception('offline');
    await tester.tap(submit());
    await tester.pumpAndSettle();
    expect(
      find.text('Das hat nicht geklappt. Versuch es später nochmal.'),
      findsOneWidget,
    );
    expect(find.byType(DietitianConnectScreen), findsOneWidget);
  });

  testWidgets('back from step 2 returns to step 1', (tester) async {
    await pump(tester);
    await lookUp(tester, 'BERGER-7K2');
    // The system back, as a gesture or the button sends it.
    unawaited(
      Navigator.of(
        tester.element(find.byType(DietitianConnectScreen)),
      ).maybePop(),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DietitianConnectScreen), findsOneWidget);
    expect(codeField(), findsOneWidget);
    expect(find.text('Gefunden'), findsNothing);
  });

  testWidgets('with 3 active connections the limit line replaces the field', (
    tester,
  ) async {
    await pump(
      tester,
      shares: [
        testDietitianShare(id: 'a'),
        testDietitianShare(id: 'b'),
        testDietitianShare(id: 'c'),
      ],
    );
    // The list's own button is off then; the route stays reachable.
    expect(find.byType(DietitianConnectScreen), findsOneWidget);
    expect(find.text(_limit), findsOneWidget);
    expect(codeField(), findsNothing);
    expect(find.text('QR-Code scannen'), findsNothing);
  });

  group('PracticeCodeScanner', () {
    testWidgets('pops with the first value practiceCodeFromScan accepts', (
      tester,
    ) async {
      late ValueChanged<List<String?>> feed;
      String? result = 'unset';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => PracticeCodeScanner(
                      camera: (_, onScan) {
                        feed = onScan;
                        return const SizedBox();
                      },
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      feed([null]);
      await tester.pump();
      // Nothing readable: no line.
      expect(find.text(PracticeCodeScanner.rejectedLine), findsNothing);
      feed([null, 'kein Code!', 'https://evil.test/c/BERGER-7K2']);
      await tester.pump();
      // A rejected QR code says so; the scanner keeps running.
      expect(find.byType(PracticeCodeScanner), findsOneWidget);
      expect(find.text(PracticeCodeScanner.rejectedLine), findsOneWidget);
      // It sits on the scrim, so it reads at ≥ 4.5:1 even over a white
      // camera picture.
      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text(PracticeCodeScanner.rejectedLine),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).color, AppTheme.scrim);
      final behind = Color.alphaBlend(AppTheme.scrim, Colors.white);
      expect(
        1.05 / (behind.computeLuminance() + 0.05),
        greaterThanOrEqualTo(4.5),
      );
      feed(['https://connect.bellybuddy.at/c/berger-7k2', 'ANNA-ABC']);
      // A second detection while popping is ignored.
      feed(['ANNA-ABC']);
      await tester.pumpAndSettle();
      expect(result, 'BERGER-7K2');
      expect(find.byType(PracticeCodeScanner), findsNothing);
    });

    testWidgets('without camera permission it says the code can be typed', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => scannerErrorView(
              context,
              const MobileScannerException(
                errorCode: MobileScannerErrorCode.permissionDenied,
              ),
            ),
          ),
        ),
      );
      expect(
        find.text('Ohne Kamera kannst du den Code auch eintippen.'),
        findsOneWidget,
      );
    });
  });
}
