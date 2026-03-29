import 'package:belly_buddy/app.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/config/splash_screen_config.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/splash_screen_provider.dart';
import 'package:belly_buddy/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/helpers/fakes.dart';
import '../../test/helpers/fixtures.dart';

ProviderScope buildTestApp({
  String? userId = testUserId,
  bool authenticated = true,
  FakeProfileRepository? profileRepo,
  FakeEntryRepository? entryRepo,
  FakeDrinkRepository? drinkRepo,
  bool seedProfile = true,
}) {
  final fakeProfileRepo = profileRepo ?? FakeProfileRepository();
  if (seedProfile) {
    fakeProfileRepo.seedProfile(testUserProfile());
  }

  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue(userId),
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository()..signedIn = authenticated,
      ),
      profileRepositoryProvider.overrideWithValue(fakeProfileRepo),
      entryRepositoryProvider.overrideWithValue(
        entryRepo ?? FakeEntryRepository(),
      ),
      drinkRepositoryProvider.overrideWithValue(
        drinkRepo ?? FakeDrinkRepository(),
      ),
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
      splashConfigProvider.overrideWithValue(SplashConfig.test),
    ],
    child: const BellyBuddyApp(),
  );
}

Future<void> setNotificationModalShown() async {
  SharedPreferences.setMockInitialValues({
    AppConstants.keyNotificationModalShown: true,
  });
}
