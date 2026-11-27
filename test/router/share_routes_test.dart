import 'dart:async';

import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/router/app_router.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/shares/dietitian_connect_screen.dart';
import 'package:belly_buddy/screens/shares/dietitian_share_edit_screen.dart';
import 'package:belly_buddy/services/share_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_host.dart';
import '../helpers/share_fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('de_DE'));

  Future<ProviderContainer> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer.test(
      overrides: [
        ...baseOverrides(),
        shareServiceProvider.overrideWithValue(
          FakeShareService([testDietitianShare(id: 'd1')]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AppTestHost(),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(isAuthenticatedProvider), isTrue);
    return container;
  }

  testWidgets('/shares/connect opens the connect screen', (tester) async {
    final container = await pump(tester);
    unawaited(container.read(routerProvider).push(RoutePaths.dietitianConnect));
    await tester.pumpAndSettle();
    expect(find.byType(DietitianConnectScreen), findsOneWidget);
  });

  testWidgets('/shares/:id/edit opens the edit screen of that share', (
    tester,
  ) async {
    final container = await pump(tester);
    unawaited(
      container
          .read(routerProvider)
          .push(RoutePaths.dietitianShareEditFor('d1')),
    );
    await tester.pumpAndSettle();
    final screen = tester.widget<DietitianShareEditScreen>(
      find.byType(DietitianShareEditScreen),
    );
    expect(screen.id, 'd1');
    expect(find.text('Freigabe ändern'), findsOneWidget);
  });
}
