import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/user_profile.dart';
import 'profile_provider.dart';

/// Whether [profile] lacks a GDPR Art. 9 health-data consent for the current
/// privacy policy version. A missing profile row (signed out, or signed up
/// but still in the registration wizard) needs no consent yet: the gate
/// applies as soon as the row exists.
bool needsHealthConsent(UserProfile? profile) {
  if (profile == null) return false;
  return profile.healthConsentAt == null ||
      profile.privacyPolicyVersion != AppConstants.privacyPolicyVersion;
}

/// Whether [profile] consented to an older privacy policy version than the
/// current one: the consent screen then asks again and says the policy
/// changed. False for a first-time consent.
bool consentedToOlderPolicy(UserProfile? profile) =>
    profile?.healthConsentAt != null && needsHealthConsent(profile);

/// True while the signed-in user's profile is loaded and lacks a current
/// health-data consent. The router redirect sends every location to
/// `/health-consent` while it is set (the upgrade hard gate still wins).
///
/// Only a loaded profile ([AsyncData]) changes the flag: while the profile is
/// loading (cold start, or a `fetchProfile` refresh) or failed to load, the
/// previous value is kept, so the gate neither flashes before the profile
/// arrives nor drops for a frame during a refresh. Sign-out resets the
/// profile to `data(null)`, which clears the flag.
class HealthConsentRequiredNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen<AsyncValue<UserProfile?>>(profileProvider, (_, next) {
      if (next case AsyncData(:final value)) {
        state = needsHealthConsent(value);
      }
    });
    final current = ref.read(profileProvider);
    return current is AsyncData<UserProfile?> &&
        needsHealthConsent(current.value);
  }
}

final healthConsentRequiredProvider =
    NotifierProvider<HealthConsentRequiredNotifier, bool>(
      HealthConsentRequiredNotifier.new,
    );
