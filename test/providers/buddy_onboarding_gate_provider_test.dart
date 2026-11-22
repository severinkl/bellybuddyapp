import 'dart:async';

import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/providers/buddy_onboarding_gate_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/router/app_router.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/riverpod_helpers.dart';

BuddyStatus _status({required bool hasRow, DateTime? completedAt}) =>
    BuddyStatus(
      state: BuddyState(
        userId: testUserId,
        name: 'Bauchi',
        onboardingCompletedAt: completedAt,
      ),
      hasRow: hasRow,
      streak: 0,
      todayCounted: false,
    );

/// A Buddy repository whose [fetch] blocks until [release] is called.
class _BlockingBuddyRepository extends FakeBuddyRepository {
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<BuddyState?> fetch(String userId) async {
    await _gate.future;
    return super.fetch(userId);
  }
}

void main() {
  group('needsBuddyOnboarding', () {
    final complete = AsyncValue<UserProfile?>.data(testUserProfile());
    final noRow = AsyncValue<BuddyStatus?>.data(_status(hasRow: false));
    final error = StateError('backend down');

    bool gate({
      bool isAuthenticated = true,
      AsyncValue<UserProfile?>? profile,
      AsyncValue<BuddyStatus?>? buddy,
    }) => needsBuddyOnboarding(
      isAuthenticated: isAuthenticated,
      profile: profile ?? complete,
      buddy: buddy ?? noRow,
    );

    test('signed out: false', () {
      expect(gate(isAuthenticated: false), isFalse);
    });

    test('no profile row (still in the wizard): false', () {
      expect(gate(profile: const AsyncValue.data(null)), isFalse);
    });

    test('profile loading or failed: false', () {
      expect(gate(profile: const AsyncValue.loading()), isFalse);
      expect(gate(profile: AsyncValue.error(error, StackTrace.empty)), isFalse);
    });

    test('incomplete profile: false', () {
      final incomplete = testUserProfile().copyWith(diet: null);
      expect(incomplete.isComplete, isFalse);
      expect(gate(profile: AsyncValue.data(incomplete)), isFalse);
    });

    test('health consent missing (the consent gate comes first): false', () {
      expect(
        gate(
          profile: AsyncValue.data(testUserProfile(hasHealthConsent: false)),
        ),
        isFalse,
      );
      expect(
        gate(
          profile: AsyncValue.data(
            testUserProfile(privacyPolicyVersion: '2020-01-01'),
          ),
        ),
        isFalse,
      );
    });

    test('Buddy loading: false (no flash before it is known)', () {
      expect(gate(buddy: const AsyncValue.loading()), isFalse);
    });

    test('Buddy failed to load: false (never block on a backend error)', () {
      expect(gate(buddy: AsyncValue.error(error, StackTrace.empty)), isFalse);
    });

    test('Buddy signed out (null): false', () {
      expect(gate(buddy: const AsyncValue.data(null)), isFalse);
    });

    test('no Buddy row (existing user from before the Buddy): true', () {
      expect(gate(), isTrue);
    });

    test('a row without onboardingCompletedAt (app killed mid-flow): true', () {
      expect(gate(buddy: AsyncValue.data(_status(hasRow: true))), isTrue);
    });

    test('onboarding completed: false', () {
      expect(
        gate(
          buddy: AsyncValue.data(
            _status(hasRow: true, completedAt: DateTime(2026, 11, 1)),
          ),
        ),
        isFalse,
      );
    });
  });

  group('buddyOnboardingRedirect', () {
    test('required: the shell roots go to /buddy-onboarding', () {
      for (final path in [RoutePaths.dashboard, RoutePaths.diary]) {
        expect(
          buddyOnboardingRedirect(isRequired: true, path: path),
          RoutePaths.buddyOnboarding,
          reason: path,
        );
      }
    });

    test('required: everything else stays (pushes from inside the flow, '
        'the wizard, the onboarding itself)', () {
      for (final path in [
        RoutePaths.buddyOnboarding,
        RoutePaths.registration,
        RoutePaths.mealTracker,
        RoutePaths.drinkTracker,
        RoutePaths.recipeNew,
        RoutePaths.settings,
        RoutePaths.recommendations,
        RoutePaths.recipes,
        RoutePaths.welcome,
        RoutePaths.auth,
        '/meal-tracker/some-id',
      ]) {
        expect(
          buddyOnboardingRedirect(isRequired: true, path: path),
          isNull,
          reason: path,
        );
      }
    });

    test('not required: nothing moves, not even away from the onboarding '
        '(it completes at the gift and leaves by itself)', () {
      for (final path in [
        RoutePaths.buddyOnboarding,
        RoutePaths.dashboard,
        RoutePaths.diary,
        RoutePaths.mealTracker,
      ]) {
        expect(
          buddyOnboardingRedirect(isRequired: false, path: path),
          isNull,
          reason: path,
        );
      }
    });

    test('the gated paths are exactly the shell branch roots', () {
      final container = createContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(signedIn: false),
          ),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
          buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
        ],
      );
      final router = container.read(routerProvider);
      addTearDown(router.dispose);

      final shell = router.configuration.routes
          .whereType<StatefulShellRoute>()
          .single;
      final branchRoots = {
        for (final branch in shell.branches)
          for (final route in branch.routes.whereType<GoRoute>()) route.path,
      };
      expect(branchRoots, buddyOnboardingGatedPaths);
    });
  });

  group('buddyOnboardingRequiredProvider', () {
    ProviderContainer containerFor({
      bool signedIn = true,
      UserProfile? profile,
      FakeBuddyRepository? buddyRepo,
    }) {
      final profiles = FakeProfileRepository();
      if (profile != null) profiles.seedProfile(profile);
      final container = createContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(signedIn: signedIn),
          ),
          profileRepositoryProvider.overrideWithValue(profiles),
          entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
          buddyRepositoryProvider.overrideWithValue(
            buddyRepo ?? FakeBuddyRepository(),
          ),
        ],
      );
      container.listen(buddyOnboardingRequiredProvider, (_, _) {});
      return container;
    }

    test('true once profile and Buddy are loaded without a row; false after '
        'completeOnboarding', () async {
      final container = containerFor(profile: testUserProfile());
      expect(container.read(buddyOnboardingRequiredProvider), isFalse);

      await container.read(profileProvider.notifier).fetchProfile();
      await container.read(buddyProvider.future);
      expect(container.read(buddyOnboardingRequiredProvider), isTrue);

      await container.read(buddyProvider.notifier).completeOnboarding();
      expect(container.read(buddyOnboardingRequiredProvider), isFalse);
    });

    test('a named Buddy without completion stays required', () async {
      final buddyRepo = FakeBuddyRepository()
        ..store[testUserId] = const BuddyState(
          userId: testUserId,
          name: 'Bauchi',
        );
      final container = containerFor(
        profile: testUserProfile(),
        buddyRepo: buddyRepo,
      );
      await container.read(profileProvider.notifier).fetchProfile();
      await container.read(buddyProvider.future);

      expect(container.read(buddyOnboardingRequiredProvider), isTrue);
    });

    test('false while the Buddy loads, then true', () async {
      final buddyRepo = _BlockingBuddyRepository();
      final container = containerFor(
        profile: testUserProfile(),
        buddyRepo: buddyRepo,
      );
      await container.read(profileProvider.notifier).fetchProfile();
      final buddy = container.read(buddyProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(buddyProvider).isLoading, isTrue);
      expect(container.read(buddyOnboardingRequiredProvider), isFalse);

      buddyRepo.release();
      await buddy;
      expect(container.read(buddyOnboardingRequiredProvider), isTrue);
    });

    test('false when the Buddy fails to load', () async {
      final container = containerFor(
        profile: testUserProfile(),
        buddyRepo: FakeBuddyRepository()..throwOnFetch = true,
      );
      await container.read(profileProvider.notifier).fetchProfile();
      await expectLater(
        container.read(buddyProvider.future),
        throwsA(anything),
      );

      expect(container.read(buddyProvider).hasError, isTrue);
      expect(container.read(buddyOnboardingRequiredProvider), isFalse);
    });

    test('the Buddy is loaded only once the profile is ready', () async {
      final buddyRepo = FakeBuddyRepository();
      final container = containerFor(
        profile: testUserProfile(),
        buddyRepo: buddyRepo,
      );
      // Profile still loading: the gate doesn't touch the Buddy.
      expect(container.read(buddyOnboardingRequiredProvider), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(buddyRepo.fetchCount, 0);

      await container.read(profileProvider.notifier).fetchProfile();
      await container.read(buddyProvider.future);
      expect(buddyRepo.fetchCount, 1);
      expect(container.read(buddyOnboardingRequiredProvider), isTrue);
    });

    test('an incomplete profile never loads the Buddy', () async {
      final buddyRepo = FakeBuddyRepository();
      final container = containerFor(
        profile: testUserProfile().copyWith(diet: null),
        buddyRepo: buddyRepo,
      );
      await container.read(profileProvider.notifier).fetchProfile();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(buddyOnboardingRequiredProvider), isFalse);
      expect(buddyRepo.fetchCount, 0);
    });

    test('false when signed out', () async {
      final container = containerFor(
        signedIn: false,
        profile: testUserProfile(),
      );
      await container.read(profileProvider.notifier).fetchProfile();

      expect(container.read(buddyOnboardingRequiredProvider), isFalse);
    });
  });
}
