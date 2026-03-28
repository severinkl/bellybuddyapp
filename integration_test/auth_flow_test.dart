import 'package:belly_buddy/config/splash_screen_config.dart';
import 'package:belly_buddy/providers/splash_screen_provider.dart';
import 'package:belly_buddy/screens/welcome/welcome_screen.dart';
import 'package:belly_buddy/screens/auth/auth_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:belly_buddy/app.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/repositories.dart';

import '../test/helpers/fakes.dart';
import '../test/helpers/fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  List<Override> buildOverrides({
    String? userId,
    bool authenticated = true,
  }) => [
    currentUserIdProvider.overrideWithValue(userId),
    authRepositoryProvider.overrideWithValue(
      FakeAuthRepository()..signedIn = authenticated,
    ),
    profileRepositoryProvider.overrideWithValue(
      FakeProfileRepository()..seedProfile(testUserProfile()),
    ),
    entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
    drinkRepositoryProvider.overrideWithValue(FakeDrinkRepository()),
    ingredientRepositoryProvider.overrideWithValue(FakeIngredientRepository()),
    recipeRepositoryProvider.overrideWithValue(FakeRecipeRepository()),
    recommendationRepositoryProvider.overrideWithValue(
      FakeRecommendationRepository(),
    ),
    mealMediaRepositoryProvider.overrideWithValue(FakeMealMediaRepository()),
    notificationRepositoryProvider.overrideWithValue(
      FakeNotificationRepository(),
    ),
    splashConfigProvider.overrideWithValue(SplashConfig.test),
  ];

  testWidgets('unauthenticated user (null userId) sees welcome screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(userId: null, authenticated: false),
        child: const BellyBuddyApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Unauthenticated user should be redirected to the welcome screen
    expect(find.byKey(WelcomeScreen.registrationButtonKey), findsOneWidget);
  });

  testWidgets(
    'unauthenticated user can navigate to auth screen and submit credentials',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(userId: null, authenticated: false),
          child: const BellyBuddyApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify we're on the welcome screen
      expect(find.byKey(WelcomeScreen.signInButtonKey), findsOneWidget);
      expect(find.byKey(WelcomeScreen.registrationButtonKey), findsOneWidget);

      // Tap the sign-in button to navigate to auth screen
      await tester.tap(find.byKey(WelcomeScreen.signInButtonKey));
      await tester.pumpAndSettle();

      // Verify we're on the auth screen by finding the email field
      expect(find.byKey(AuthScreen.emailFieldKey), findsOneWidget);
      expect(find.byKey(AuthScreen.passwordFieldKey), findsOneWidget);

      // Enter dummy credentials
      await tester.enterText(
        find.byKey(AuthScreen.emailFieldKey),
        'test@example.com',
      );
      await tester.enterText(
        find.byKey(AuthScreen.passwordFieldKey),
        'TestPassword123',
      );
      await tester.pumpAndSettle();

      // Verify the submit button exists and tap it
      expect(find.byKey(AuthScreen.submitLoginButtonKey), findsOneWidget);
      await tester.tap(find.byKey(AuthScreen.submitLoginButtonKey));
      await tester.pumpAndSettle();
    },
  );
}
