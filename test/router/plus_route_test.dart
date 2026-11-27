import 'dart:async';

import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/plus_provider.dart';
import 'package:belly_buddy/router/app_router.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/plus/plus_screen.dart';
import 'package:belly_buddy/services/purchases/purchases_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_host.dart';
import '../helpers/purchases_fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('de_DE'));

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required bool enabled,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final gateway = FakePurchasesGateway(offerAnswer: testPlusOffer());
    addTearDown(gateway.dispose);
    final container = ProviderContainer.test(
      overrides: [
        ...baseOverrides(),
        paywallEnabledProvider.overrideWithValue(enabled),
        purchasesGatewayProvider.overrideWithValue(gateway),
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

  testWidgets('switch off: /plus redirects to Home', (tester) async {
    final container = await pump(tester, enabled: false);
    final router = container.read(routerProvider);
    router.go(RoutePaths.plus);
    await tester.pumpAndSettle();
    expect(find.byType(PlusScreen), findsNothing);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      RoutePaths.dashboard,
    );
  });

  testWidgets('switch on: /plus opens the paywall', (tester) async {
    final container = await pump(tester, enabled: true);
    unawaited(container.read(routerProvider).push(RoutePaths.plus));
    await tester.pumpAndSettle();
    expect(find.byType(PlusScreen), findsOneWidget);
  });
}
