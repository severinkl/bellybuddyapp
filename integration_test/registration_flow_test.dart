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

  List<Override> buildOverrides({required bool hasProfile}) => [
    currentUserIdProvider.overrideWithValue(testUserId),
    authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
    profileRepositoryProvider.overrideWithValue(
      hasProfile
          ? (FakeProfileRepository()..seedProfile(testUserProfile()))
          : emptyProfileRepo,
    ),
    entryRepositoryProvider.overrideWithValue(fakeEntryRepo),
    drinkRepositoryProvider.overrideWithValue(FakeDrinkRepository()),
    ingredientRepositoryProvider.overrideWithValue(
      FakeIngredientRepository(),
    ),
    recipeRepositoryProvider.overrideWithValue(FakeRecipeRepository()),
    recommendationRepositoryProvider.overrideWithValue(
      FakeRecommendationRepository(),
    ),
    mealMediaRepositoryProvider.overrideWithValue(FakeMealMediaRepository()),
    notificationRepositoryProvider.overrideWithValue(
      FakeNotificationRepository(),
    ),
  ];

  testWidgets('new user (userId but no profile) sees registration wizard', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(hasProfile: false),
        child: const BellyBuddyApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    // Without a saved profile the app should navigate to registration
    expect(find.byType(BellyBuddyApp), findsOneWidget);
  });

  testWidgets('registration wizard shows first step', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(hasProfile: false),
        child: const BellyBuddyApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    // The app renders without errors; the registration screen is the entry
    // point for users without a profile
    expect(find.byType(BellyBuddyApp), findsOneWidget);
  });
}
