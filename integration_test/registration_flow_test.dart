import 'package:belly_buddy/config/splash_screen_config.dart';
import 'package:belly_buddy/providers/splash_screen_provider.dart';
import 'package:belly_buddy/screens/registration/registration_wizard_screen.dart';
import 'package:belly_buddy/screens/registration/steps/auth_step.dart';
import 'package:belly_buddy/screens/registration/steps/birth_year_step.dart';
import 'package:belly_buddy/screens/registration/steps/diet_step.dart';
import 'package:belly_buddy/screens/registration/steps/gender_step.dart';
import 'package:belly_buddy/screens/registration/steps/height_weight_step.dart';
import 'package:belly_buddy/screens/registration/steps/intolerances_step.dart';
import 'package:belly_buddy/screens/registration/steps/symptoms_step.dart';
import 'package:belly_buddy/screens/welcome/welcome_screen.dart';
import 'package:belly_buddy/widgets/common/bb_password_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
// ignore: invalid_use_of_internal_member
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/app.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/drink_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';

import '../test/helpers/fakes.dart';
import '../test/helpers/fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeProfileRepository emptyProfileRepo;
  late FakeEntryRepository fakeEntryRepo;

  setUp(() {
    // Profile repo with NO seeded profile — simulates new user
    emptyProfileRepo = FakeProfileRepository();
    fakeEntryRepo = FakeEntryRepository();
  });

  List<Override> buildOverrides({
    required bool hasProfile,
    bool authenticated = false,
  }) => [
    currentUserIdProvider.overrideWithValue(testUserId),
    authRepositoryProvider.overrideWithValue(
      FakeAuthRepository()..signedIn = authenticated,
    ),
    profileRepositoryProvider.overrideWithValue(
      hasProfile
          ? (FakeProfileRepository()..seedProfile(testUserProfile()))
          : emptyProfileRepo,
    ),
    entryRepositoryProvider.overrideWithValue(fakeEntryRepo),
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

  testWidgets('new user should see welcome screen and registration button', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(hasProfile: false),
        child: const BellyBuddyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // New user (no profile) should be redirected to the welcome screen
    expect(find.byKey(WelcomeScreen.registrationButtonKey), findsOneWidget);
  });

  testWidgets(
    'new user should tap on registration button and go through registration process',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(hasProfile: false),
          child: const BellyBuddyApp(),
        ),
      );
      await tester.pumpAndSettle();

      final registrationButton = find.byKey(
        WelcomeScreen.registrationButtonKey,
      );

      // New user (no profile) should be redirected to the welcome screen
      expect(registrationButton, findsOneWidget);

      // Tap on the registration button
      await tester.tap(registrationButton);
      await tester.pumpAndSettle();

      final nextButtonKey = find.byKey(RegistrationWizardScreen.nextButtonKey);

      // Step 1: Birth Year
      expect(find.byKey(BirthYearStep.birthYearTitleKey), findsOneWidget);
      await tester.tap(nextButtonKey);
      await tester.pumpAndSettle();

      // Step 2: Gender - Select "Männlich" option
      expect(find.byKey(GenderStep.genderTitleKey), findsOneWidget);
      await tester.tap(find.byKey(GenderStep.genderMaennlichKey));
      await tester.pumpAndSettle();

      // Tap Next button to proceed
      await tester.tap(nextButtonKey);
      await tester.pumpAndSettle();

      // Step 3: Height & Weight - Verify title is shown
      expect(find.byKey(HeightWeightStep.heightWeightTitleKey), findsOneWidget);

      // Tap Next button to proceed
      await tester.tap(nextButtonKey);
      await tester.pumpAndSettle();

      // Step 4: Diet - Select "Alles" option
      expect(find.byKey(DietStep.dietTitleKey), findsOneWidget);
      await tester.tap(find.byKey(DietStep.dietAllesKey));
      await tester.pumpAndSettle();

      // Tap Next button to proceed
      await tester.tap(nextButtonKey);
      await tester.pumpAndSettle();

      // Step 5: Symptoms - Verify title is shown
      expect(find.byKey(SymptomsStep.symptomsTitleKey), findsOneWidget);

      // Tap Next button to proceed
      await tester.tap(nextButtonKey);
      await tester.pumpAndSettle();

      // Step 6: Intolerances - Verify title is shown
      expect(find.byKey(IntolerancesStep.intolerancesTitleKey), findsOneWidget);

      // Tap Next button to proceed
      await tester.tap(nextButtonKey);
      await tester.pumpAndSettle();

      // Step 7: Auth - Verify email/password fields are shown
      expect(find.byKey(AuthStep.emailFieldKey), findsOneWidget);
      expect(find.byKey(BbPasswordField.passwordFieldKey), findsOneWidget);
    },
  );
}
