import 'dart:async';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/providers/health_consent_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/riverpod_helpers.dart';

/// Blocks every [getProfile] call until [release] is called.
class _BlockingProfileRepository extends FakeProfileRepository {
  Completer<void> _gate = Completer<void>();

  void release() {
    _gate.complete();
    _gate = Completer<void>();
  }

  @override
  Future<UserProfile?> getProfile(String userId) async {
    await _gate.future;
    return super.getProfile(userId);
  }
}

void main() {
  group('needsHealthConsent', () {
    test('false without a profile row', () {
      expect(needsHealthConsent(null), isFalse);
    });

    test('false with a consent for the current policy version', () {
      expect(needsHealthConsent(testUserProfile()), isFalse);
    });

    test('true without a consent timestamp', () {
      expect(
        needsHealthConsent(
          testUserProfile(
            hasHealthConsent: false,
            privacyPolicyVersion: AppConstants.privacyPolicyVersion,
          ),
        ),
        isTrue,
      );
    });

    test('true for an outdated policy version', () {
      expect(
        needsHealthConsent(testUserProfile(privacyPolicyVersion: '2020-01-01')),
        isTrue,
      );
    });
  });

  group('healthConsentRequiredProvider', () {
    test('false while the profile loads, true once it is loaded without '
        'consent, and kept through a reload', () async {
      final profiles = _BlockingProfileRepository()
        ..seedProfile(testUserProfile(hasHealthConsent: false));
      final container = createContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          profileRepositoryProvider.overrideWithValue(profiles),
        ],
      );
      container.listen(healthConsentRequiredProvider, (_, _) {});

      final first = container.read(profileProvider.notifier).fetchProfile();
      expect(container.read(healthConsentRequiredProvider), isFalse);
      profiles.release();
      await first;
      expect(container.read(healthConsentRequiredProvider), isTrue);

      // A refresh puts the profile back into loading; the gate must not drop.
      final reload = container.read(profileProvider.notifier).fetchProfile();
      expect(container.read(profileProvider).isLoading, isTrue);
      expect(container.read(healthConsentRequiredProvider), isTrue);
      profiles.release();
      await reload;
      expect(container.read(healthConsentRequiredProvider), isTrue);
    });

    test('accepting lifts the gate; sign-out reset clears it', () async {
      final profiles = FakeProfileRepository()
        ..seedProfile(testUserProfile(hasHealthConsent: false));
      final container = createContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          profileRepositoryProvider.overrideWithValue(profiles),
        ],
      );
      container.listen(healthConsentRequiredProvider, (_, _) {});

      await container.read(profileProvider.notifier).fetchProfile();
      expect(container.read(healthConsentRequiredProvider), isTrue);

      await container.read(profileProvider.notifier).acceptHealthConsent();
      expect(container.read(healthConsentRequiredProvider), isFalse);
      expect(profiles.acceptHealthConsentCount, 1);

      profiles.seedProfile(testUserProfile(hasHealthConsent: false));
      await container.read(profileProvider.notifier).fetchProfile();
      expect(container.read(healthConsentRequiredProvider), isTrue);

      container.read(profileProvider.notifier).reset();
      expect(container.read(healthConsentRequiredProvider), isFalse);
    });
  });
}
