import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/config/constants.dart';

void main() {
  group('AppConstants.resetPasswordRedirectUrl', () {
    test('points at the Belly Buddy web app', () {
      expect(
        AppConstants.resetPasswordRedirectUrl,
        startsWith('https://app.bellybuddy.at/'),
      );
    });

    test('no longer references the Lovable host', () {
      expect(
        AppConstants.resetPasswordRedirectUrl.toLowerCase(),
        isNot(contains('lovable')),
      );
    });
  });

  test('the privacy policy version is pinned to core and the admin', () {
    expect(AppConstants.privacyPolicyVersion, '2026-12-01');
  });
}
