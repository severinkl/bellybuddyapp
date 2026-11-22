import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../router/route_names.dart';
import 'auth_provider.dart';
import 'buddy_provider.dart';
import 'health_consent_provider.dart';
import 'profile_provider.dart';

/// Whether a signed-in user still has to go through the Buddy onboarding:
/// their profile is loaded, complete and consented, and their Buddy is
/// loaded without a completed onboarding (no `buddy_state` row yet, as for
/// users from before the Buddy, or a row without `onboardingCompletedAt`,
/// as when the app was killed mid-onboarding).
///
/// Anything not loaded yet or failed to load counts as "not required": the
/// gate never blocks the app on a backend error or flashes before the
/// Buddy is known. A missing or incomplete profile (still in the wizard) and
/// a missing health consent (its own gate comes first) don't gate either.
bool needsBuddyOnboarding({
  required bool isAuthenticated,
  required AsyncValue<UserProfile?> profile,
  required AsyncValue<BuddyStatus?> buddy,
}) {
  if (!isAuthenticated) return false;
  if (profile is! AsyncData<UserProfile?> ||
      buddy is! AsyncData<BuddyStatus?>) {
    return false;
  }
  final user = profile.value;
  final status = buddy.value;
  if (user == null || !user.isComplete || needsHealthConsent(user)) {
    return false;
  }
  if (status == null) return false;
  return !status.hasRow || status.state.onboardingCompletedAt == null;
}

/// True while [needsBuddyOnboarding] holds for the signed-in user. The
/// router redirect sends every location outside
/// [buddyOnboardingAllowedPaths] to `/buddy-onboarding` while it is set.
final buddyOnboardingRequiredProvider = Provider<bool>(
  (ref) => needsBuddyOnboarding(
    isAuthenticated: ref.watch(isAuthenticatedProvider),
    profile: ref.watch(profileProvider),
    buddy: ref.watch(buddyProvider),
  ),
);

/// Locations a user who still needs the Buddy onboarding may open: the
/// onboarding itself, the registration wizard (it hands over to the
/// onboarding) and the trackers the onboarding's first-meal step pushes.
const buddyOnboardingAllowedPaths = {
  RoutePaths.buddyOnboarding,
  RoutePaths.registration,
  RoutePaths.mealTracker,
  RoutePaths.drinkTracker,
};

/// The redirect for [path]: `/buddy-onboarding` while the onboarding is
/// [required] and [path] isn't allowed, otherwise null (stay).
///
/// Deliberately nothing the other way: the onboarding completes when the
/// gift opens, before the user has read it, and the screen moves on to the
/// dashboard by itself.
String? buddyOnboardingRedirect({
  required bool required,
  required String path,
}) => required && !buddyOnboardingAllowedPaths.contains(path)
    ? RoutePaths.buddyOnboarding
    : null;
