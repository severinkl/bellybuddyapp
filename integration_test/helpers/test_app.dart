import 'package:belly_buddy/app.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/config/splash_screen_config.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/splash_screen_provider.dart';
import 'package:belly_buddy/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../test/helpers/fakes.dart';
import '../../test/helpers/fixtures.dart';

final testCurrentUserProvider = StateProvider<User?>((ref) => null);

User? _buildTestUser() {
  return User.fromJson({
    'id': testUserId,
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': DateTime.now().toIso8601String(),
  });
}

ProviderScope buildTestApp({
  bool authenticated = true,
  bool seedProfile = true,
  bool dynamicAuth = false,
  bool failEmailSignIn = false,
  String signInErrorMessage = 'Login failed',
  FakeProfileRepository? profileRepo,
  FakeEntryRepository? entryRepo,
  FakeDrinkRepository? drinkRepo,
}) {
  final fakeProfileRepo = profileRepo ?? FakeProfileRepository();
  if (seedProfile) {
    fakeProfileRepo.seedProfile(testUserProfile());
  }

  final initialUser = authenticated ? _buildTestUser() : null;

  late final FakeAuthRepository fakeAuthRepository;

  if (dynamicAuth) {
    fakeAuthRepository = FakeAuthRepository(
      signedIn: authenticated,
      shouldFailEmailSignIn: failEmailSignIn,
      signInErrorMessage: signInErrorMessage,
      onSignedIn: (_) {},
      onSignedOut: () {},
    );
  } else {
    fakeAuthRepository = FakeAuthRepository(
      signedIn: authenticated,
      shouldFailEmailSignIn: failEmailSignIn,
      signInErrorMessage: signInErrorMessage,
    );
  }

  return ProviderScope(
    overrides: [
      testCurrentUserProvider.overrideWith((ref) {
        final controller = StateController<User?>(initialUser);

        if (dynamicAuth) {
          fakeAuthRepository.onSignedIn = (user) {
            controller.state = user;
          };
          fakeAuthRepository.onSignedOut = () {
            controller.state = null;
          };
        }

        return controller.state;
      }),

      currentUserProvider.overrideWith((ref) {
        if (dynamicAuth) {
          return ref.watch(testCurrentUserProvider);
        }
        return initialUser;
      }),

      authRepositoryProvider.overrideWithValue(fakeAuthRepository),

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
