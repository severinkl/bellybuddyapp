import 'package:belly_buddy/app.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/config/splash_screen_config.dart';
import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/models/insight_source.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/splash_screen_provider.dart';
import 'package:belly_buddy/providers/upgrade_gate_provider.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/repositories/knowledge_repository.dart';
import 'package:belly_buddy/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../test/helpers/ambient_animations.dart';
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
/// [weeklyTipsEnabled] goes into the seeded profile. The blog articles are
/// [testKnowledgeArticles] (no network). The recipe collection is
/// [recipeRepo] (default: one recipe that fits everyone).
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
  FakeRecipeRepository? recipeRepo,
  FakeUserRecipeRepository? userRecipeRepo,
  FakeBuddyRepository? buddyRepo,
  FakeRecommendationRepository? recommendationRepo,
  FakeIngredientRepository? ingredientRepo,
  bool weeklyTipsEnabled = false,
}) {
  // Animated Buddies (dashboard hero, welcome screen) tick every frame, the
  // care ring's glow pulses and the streak flame flickers forever, so
  // `pumpAndSettle` would never settle: hold them still.
  disableAmbientAnimationsForTests();

  final fakeProfileRepo = profileRepo ?? FakeProfileRepository();
  if (seedProfile) {
    fakeProfileRepo.seedProfile(
      testUserProfile(weeklyTipsEnabled: weeklyTipsEnabled),
    );
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
        ingredientRepo ?? FakeIngredientRepository(),
      ),
      recipeRepositoryProvider.overrideWithValue(
        recipeRepo ?? FakeRecipeRepository(),
      ),
      userRecipeRepositoryProvider.overrideWithValue(
        userRecipeRepo ?? FakeUserRecipeRepository(),
      ),
      recommendationRepositoryProvider.overrideWithValue(
        recommendationRepo ?? FakeRecommendationRepository(),
      ),
      knowledgeRepositoryProvider.overrideWithValue(FakeKnowledgeRepository()),
      mealMediaRepositoryProvider.overrideWithValue(FakeMealMediaRepository()),
      notificationRepositoryProvider.overrideWithValue(
        FakeNotificationRepository(),
      ),
      buddyRepositoryProvider.overrideWithValue(fakeBuddyRepo),
      splashConfigProvider.overrideWithValue(SplashConfig.test),
      // No app_config backend: no upgrade gate.
      upgradeDecisionProvider.overrideWith(
        (_) => Future.value(UpgradeDecision.ok),
      ),
    ],
    child: const BellyBuddyApp(),
  );
}

Future<void> setNotificationModalShown() async {
  SharedPreferences.setMockInitialValues({
    AppConstants.keyNotificationModalShown: true,
  });
}

/// Noon, [daysAgo] local days back.
DateTime _noon(int daysAgo) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - daysAgo, 12);
}

GutFeelingEntry _gut(int daysAgo, {required int value}) => GutFeelingEntry(
  id: 'gut-$daysAgo',
  trackedAt: _noon(daysAgo),
  bloating: value,
  gas: value,
  cramps: value,
  fullness: value,
);

/// An insight source past the unlock: five hard days (Zwiebel in the meal
/// before 4 of them) and six good days without it.
InsightSource unlockedInsightSource() {
  const hardDaysAgo = [2, 4, 6, 8, 10];
  const goodDaysAgo = [3, 5, 7, 9, 11, 13];
  final gutFeelings = [
    for (final d in hardDaysAgo) _gut(d, value: 5),
    for (final d in goodDaysAgo) _gut(d, value: 1),
  ];
  return InsightSource(
    meals: [
      for (final d in hardDaysAgo.take(4))
        InsightMeal(
          trackedAt: _noon(d).subtract(const Duration(hours: 3)),
          ingredients: const ['Zwiebel'],
        ),
      for (final d in goodDaysAgo)
        InsightMeal(
          trackedAt: _noon(d).subtract(const Duration(hours: 3)),
          ingredients: const ['Reis'],
        ),
    ],
    gutFeelings: gutFeelings,
    activityTimes: [for (final g in gutFeelings) g.trackedAt],
  );
}
