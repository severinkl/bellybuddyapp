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
}) => isAuthenticated && _profileReady(profile) && _buddyPending(buddy);

/// The profile is loaded, complete and has a current health consent.
bool _profileReady(AsyncValue<UserProfile?> profile) => switch (profile) {
  AsyncData(value: final user?) => user.isComplete && !needsHealthConsent(user),
  _ => false,
};

/// The Buddy is loaded and its onboarding isn't completed.
bool _buddyPending(AsyncValue<BuddyStatus?> buddy) => switch (buddy) {
  AsyncData(value: final status?) =>
    !status.hasRow || status.state.onboardingCompletedAt == null,
  _ => false,
};

/// True while [needsBuddyOnboarding] holds for the signed-in user. The
/// router redirect sends the shell roots ([buddyOnboardingGatedPaths]) to
/// `/buddy-onboarding` while it is set.
///
/// The cheap auth and profile checks come first: the Buddy is only watched
/// (and so loaded) once it can matter.
final buddyOnboardingRequiredProvider = Provider<bool>((ref) {
  if (!ref.watch(isAuthenticatedProvider)) return false;
  if (!_profileReady(ref.watch(profileProvider))) return false;
  return _buddyPending(ref.watch(buddyProvider));
});

/// The locations the Buddy onboarding gate redirects: the shell roots. Every
/// way back to the app at rest (sign-in, consent, auth routes, tab switches,
/// leaving the onboarding) goes through one of them, so the gate still
/// catches the user; pushes from inside the flow (the first-meal step's
/// trackers and whatever they open) and the wizard are never redirected.
const buddyOnboardingGatedPaths = {RoutePaths.dashboard, RoutePaths.diary};

/// The redirect for [path]: `/buddy-onboarding` while the onboarding
/// [isRequired] and [path] is gated, otherwise null (stay).
///
/// Deliberately nothing the other way: the onboarding completes when the
/// gift opens, before the user has read it, and the screen moves on to the
/// dashboard by itself.
String? buddyOnboardingRedirect({
  required bool isRequired,
  required String path,
}) => isRequired && buddyOnboardingGatedPaths.contains(path)
    ? RoutePaths.buddyOnboarding
    : null;
