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

  late FakeProfileRepository fakeProfileRepo;
  late FakeEntryRepository fakeEntryRepo;

  setUp(() {
    fakeProfileRepo = FakeProfileRepository()..seedProfile(testUserProfile());
    fakeEntryRepo = FakeEntryRepository();
  });

  List<Override> buildOverrides({String? userId}) => [
    currentUserIdProvider.overrideWithValue(userId),
    authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
    profileRepositoryProvider.overrideWithValue(fakeProfileRepo),
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

  testWidgets('authenticated user with profile sees dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(userId: testUserId),
        child: const BellyBuddyApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    // Splash screen disappears and authenticated user lands on dashboard
    expect(find.byType(BellyBuddyApp), findsOneWidget);
  });

  testWidgets('unauthenticated user (null userId) sees welcome screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(userId: null),
        child: const BellyBuddyApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    // Unauthenticated user should be redirected to the welcome screen
    expect(find.textContaining('Verstehe dein Bauchgefühl'), findsOneWidget);
  });
}
