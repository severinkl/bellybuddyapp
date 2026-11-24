import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
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

/// Whether [buddyOnboardingRequiredProvider] has its answer for the
/// signed-in user: their profile has loaded (or failed) — not one left over
/// from before the sign-in — and where the gate can apply to it, the Buddy
/// has loaded (or failed). Watches the Buddy only then, like the gate.
final _gateInputsKnownProvider = Provider<bool>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final profile = ref.watch(profileProvider);
  if (profile.isLoading ||
      ref.read(profileProvider.notifier).loadedFor != userId) {
    return false;
  }
  if (!_profileReady(profile)) return true;
  return !ref.watch(buddyProvider).isLoading;
});

/// True from sign-in (or an app start with a session) until the gate knows
/// whether the user has to go through the Buddy onboarding. Meanwhile the
/// router holds the shell roots on `/loading`, so a user the gate is about
/// to send to the onboarding never sees a frame of the dashboard first.
///
/// Settles once per signed-in user: later profile or Buddy reloads never
/// hold the app again. A failed load settles it like a loaded one (the
/// gate never blocks on a backend error), and the loading screen
/// [release]s it after [AppConstants.buddyGateMaxWait] at the latest.
class BuddyOnboardingGatePendingNotifier extends Notifier<bool> {
  @override
  bool build() {
    if (ref.watch(currentUserIdProvider) == null) return false;
    final known = ref.listen<bool>(_gateInputsKnownProvider, (_, known) {
      if (known) release();
    });
    return !known.read();
  }

  /// Stops holding: the app goes on as if no onboarding were due (the gate
  /// still redirects once it knows better).
  void release() => state = false;
}

final buddyOnboardingGatePendingProvider =
    NotifierProvider<BuddyOnboardingGatePendingNotifier, bool>(
      BuddyOnboardingGatePendingNotifier.new,
    );

/// The locations the Buddy onboarding gate redirects: the shell roots. Every
/// way back to the app at rest (sign-in, consent, auth routes, tab switches,
/// leaving the onboarding) goes through one of them, so the gate still
/// catches the user; pushes from inside the flow (the first-meal step's
/// trackers and whatever they open) and the wizard are never redirected.
const buddyOnboardingGatedPaths = {RoutePaths.dashboard, RoutePaths.diary};

/// The query parameter of `/loading` naming the gated path it holds.
const _heldPathParam = 'to';

/// The redirect for [location], or null (stay). A gated path waits on
/// `/loading` (remembering itself) while the gate [isPending], then goes
/// to `/buddy-onboarding` while the onboarding [isRequired]. `/loading`
/// stays while pending, then returns to the held path (the dashboard by
/// default), which the gate checks again.
///
/// Deliberately nothing away from the onboarding: it completes on its last
/// step's answer, and the screen moves on to the dashboard by itself.
String? buddyOnboardingRedirect({
  required bool isRequired,
  required bool isPending,
  required Uri location,
}) {
  final path = location.path;
  if (path == RoutePaths.loading) {
    if (isPending) return null;
    final held = location.queryParameters[_heldPathParam];
    return buddyOnboardingGatedPaths.contains(held)
        ? held
        : RoutePaths.dashboard;
  }
  if (!buddyOnboardingGatedPaths.contains(path)) return null;
  if (isPending) {
    return Uri(
      path: RoutePaths.loading,
      queryParameters: {_heldPathParam: path},
    ).toString();
  }
  return isRequired ? RoutePaths.buddyOnboarding : null;
}
