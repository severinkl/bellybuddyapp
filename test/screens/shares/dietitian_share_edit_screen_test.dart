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
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/shares/dietitian_share_edit_screen.dart';
import 'package:belly_buddy/screens/shares/shares_screen.dart';
import 'package:belly_buddy/services/share_secrets_store.dart';
import 'package:belly_buddy/services/share_service.dart';

import '../../helpers/app_host.dart';
import '../../helpers/share_fakes.dart';

class _Service extends FakeShareService {
  _Service(super.shares);

  Object? updateFails;

  @override
  Future<void> update(String id, DietitianShareTerms terms) async {
    if (updateFails != null) throw updateFails!;
    return super.update(id, terms);
  }
}

void main() {
  late _Service service;
  late GoRouter router;

  setUpAll(() => initializeDateFormatting('de_DE', null));

  Future<void> pump(
    WidgetTester tester,
    DataShare share, {
    String? savedName,
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
    service = _Service([share]);
    final container = ProviderContainer.test(
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
            GoRoute(
              path: ':id/edit',
              builder: (_, state) =>
                  DietitianShareEditScreen(id: state.pathParameters['id']!),
            ),
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
    unawaited(router.push(RoutePaths.dietitianShareEditFor(share.id)));
    await tester.pumpAndSettle();
  }

  bool switchOn(WidgetTester tester, String label) => tester
      .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, label))
      .value;

  bool chipSelected(WidgetTester tester, String label) => tester
      .widget<FilterChip>(find.widgetWithText(FilterChip, label))
      .selected;

  Finder save() => find.widgetWithText(ElevatedButton, 'Speichern');

  testWidgets('prefilled from an open-ended share', (tester) async {
    await pump(
      tester,
      testDietitianShare(drinks: false, patterns: false, photos: true),
      savedName: 'Nicht dieser Name',
    );
    expect(find.text('Freigabe ändern'), findsOneWidget);
    expect(find.text('Das sieht Anna Berger'), findsOneWidget);
    expect(find.text('Dr. A'), findsOneWidget);
    expect(find.text('Nicht dieser Name'), findsNothing);
    expect(chipSelected(tester, '14 Tage'), isTrue);
    expect(chipSelected(tester, 'Bis ich es beende'), isTrue);
    expect(chipSelected(tester, '90 Tage'), isFalse);
    expect(switchOn(tester, 'Mahlzeiten und Zutaten'), isTrue);
    expect(switchOn(tester, 'Getränke'), isFalse);
    expect(switchOn(tester, 'Muster und Unverträglichkeiten'), isFalse);
    expect(switchOn(tester, 'Fotos der Mahlzeiten'), isTrue);
    expect(
      find.text(
        'Änderungen gelten sofort – auch für frühere Einträge im gewählten '
        'Zeitraum.',
      ),
      findsOneWidget,
    );
    expect(tester.widget<ElevatedButton>(save()).onPressed, isNotNull);
  });

  testWidgets('a share with an end date is prefilled as „90 Tage"', (
    tester,
  ) async {
    await pump(tester, testDietitianShare(expiresAt: DateTime(2027, 2, 1)));
    expect(chipSelected(tester, '90 Tage'), isTrue);
    expect(chipSelected(tester, 'Bis ich es beende'), isFalse);
  });

  testWidgets('Speichern sends the changed terms and goes back', (
    tester,
  ) async {
    await pump(tester, testDietitianShare(expiresAt: DateTime(2027, 2, 1)));
    await tester.enterText(find.byType(TextField), ' Maria ');
    await tester.tap(find.text('Bis ich es beende'));
    await tester.tap(find.text('Alles'));
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Bauchgefühl und Symptome'),
    );
    await tester.pump();
    await tester.tap(save());
    await tester.pumpAndSettle();

    final (id, t) = service.updated.single;
    expect(id, 'd1');
    expect(t.displayName, 'Maria');
    expect(t.period, SharePeriod.all);
    expect(t.duration, ShareDuration.open);
    expect(
      [t.meals, t.drinks, t.gut, t.toilet, t.patterns, t.photos],
      [true, true, false, true, false, false],
    );
    expect(find.byType(DietitianShareEditScreen), findsNothing);
    expect(find.text('Deine Freigaben'), findsOneWidget);
  });

  testWidgets('a failure shows core’s text and keeps the form', (tester) async {
    await pump(tester, testDietitianShare());
    service.updateFails = const ShareException(
      status: 403,
      message:
          'Bitte stimme zuerst der Verarbeitung deiner Gesundheitsdaten '
          'zu.',
    );
    await tester.tap(find.widgetWithText(SwitchListTile, 'Getränke'));
    await tester.pump();
    await tester.tap(save());
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Bitte stimme zuerst der Verarbeitung deiner Gesundheitsdaten zu.',
      ),
      findsOneWidget,
    );
    expect(find.byType(DietitianShareEditScreen), findsOneWidget);
    expect(switchOn(tester, 'Getränke'), isFalse);
    expect(service.updated, isEmpty);
  });

  testWidgets('Speichern needs one data switch', (tester) async {
    await pump(
      tester,
      testDietitianShare(meals: false, gut: false, toilet: false),
    );
    await tester.tap(find.widgetWithText(SwitchListTile, 'Getränke'));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(save()).onPressed, isNull);
  });

  testWidgets('an unknown or ended connection is not editable', (tester) async {
    await pump(tester, testDietitianShare(revokedAt: DateTime(2026, 11, 25)));
    expect(find.text('Diese Verbindung ist beendet.'), findsOneWidget);
    expect(save(), findsNothing);
  });
}
