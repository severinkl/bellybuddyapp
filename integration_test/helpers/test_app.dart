import 'package:belly_buddy/app.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/config/splash_screen_config.dart';
import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/splash_screen_provider.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/repositories/repositories.dart';
import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/widgets/buddy/animated_buddy.dart';
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

/// [seedBuddy] (default: [seedProfile]) stores a Buddy whose onboarding is
/// done for the test user, so existing users pass the Buddy onboarding gate
/// and land on the dashboard; a new user (no profile) has no Buddy yet.
ProviderScope buildTestApp({
  bool authenticated = true,
  bool seedProfile = true,
  bool? seedBuddy,
  bool dynamicAuth = false,
  bool failEmailSignIn = false,
  String signInErrorMessage = 'Login failed',
  String? signInEmail,
  FakeProfileRepository? profileRepo,
  FakeEntryRepository? entryRepo,
  FakeDrinkRepository? drinkRepo,
  FakeUserRecipeRepository? userRecipeRepo,
  FakeBuddyRepository? buddyRepo,
}) {
  // Animated Buddies (dashboard hero, welcome screen) tick every frame and
  // the care ring's glow pulses forever, so `pumpAndSettle` would never
  // settle: render them without ticking and the glow without pulsing.
  AnimatedBuddy.tickerEnabled = false;
  CareRing.pulseEnabled = false;

  final fakeProfileRepo = profileRepo ?? FakeProfileRepository();
  if (seedProfile) {
    fakeProfileRepo.seedProfile(testUserProfile());
  }

  final fakeBuddyRepo = buddyRepo ?? FakeBuddyRepository();
  if (seedBuddy ?? seedProfile) {
    fakeBuddyRepo.store[testUserId] = BuddyState(
      userId: testUserId,
      onboardingCompletedAt: DateTime(2026, 1, 1),
    );
  }

  final initialUser = authenticated ? _buildTestUser() : null;

  late final FakeAuthRepository fakeAuthRepository;

  if (dynamicAuth) {
    fakeAuthRepository = FakeAuthRepository(
      signedIn: authenticated,
      shouldFailEmailSignIn: failEmailSignIn,
      signInErrorMessage: signInErrorMessage,
      signInEmail: signInEmail,
      onSignedIn: (_) {},
      onSignedOut: () {},
    );
  } else {
    fakeAuthRepository = FakeAuthRepository(
      signedIn: authenticated,
      shouldFailEmailSignIn: failEmailSignIn,
      signInErrorMessage: signInErrorMessage,
      signInEmail: signInEmail,
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
      userRecipeRepositoryProvider.overrideWithValue(
        userRecipeRepo ?? FakeUserRecipeRepository(),
      ),
      recommendationRepositoryProvider.overrideWithValue(
        FakeRecommendationRepository(),
      ),
      mealMediaRepositoryProvider.overrideWithValue(FakeMealMediaRepository()),
      notificationRepositoryProvider.overrideWithValue(
        FakeNotificationRepository(),
      ),
      buddyRepositoryProvider.overrideWithValue(fakeBuddyRepo),
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
