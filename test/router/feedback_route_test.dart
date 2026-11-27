import 'dart:async';

import 'package:belly_buddy/models/feedback.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/feedback_context_provider.dart';
import 'package:belly_buddy/router/app_router.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/me/feedback_screen.dart';
import 'package:belly_buddy/screens/me/me_screen.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_host.dart';

void main() {
  setUpAll(() => initializeDateFormatting('de_DE'));

  testWidgets('/me/feedback opens the form over Ich; back returns to Ich', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer.test(
      overrides: [
        ...baseOverrides(),
        feedbackContextProvider.overrideWith(
          (_) async => const FeedbackContext(
            appVersion: '1.3.0',
            platform: 'android',
            osVersion: '14',
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AppTestHost(),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(isAuthenticatedProvider), isTrue);
    final router = container.read(routerProvider)..go(RoutePaths.me);
    await tester.pumpAndSettle();
    expect(find.byType(BbBottomNav), findsOneWidget);

    unawaited(router.push(RoutePaths.feedback));
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackScreen), findsOneWidget);
    // Over the bottom bar: pushed on the root navigator.
    expect(find.byType(BbBottomNav), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackScreen), findsNothing);
    expect(find.byType(MeScreen), findsOneWidget);
  });
}
