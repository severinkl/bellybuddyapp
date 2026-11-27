import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/models/user_profile.dart';

void main() {
  group('UserProfile.isComplete', () {
    test('true when all 5 fields non-null', () {
      const profile = UserProfile(
        birthYear: 1990,
        gender: 'männlich',
        height: 180,
        weight: 75,
        diet: 'vegetarisch',
      );
      expect(profile.isComplete, isTrue);
    });

    test('false when birthYear is null', () {
      const profile = UserProfile(
        gender: 'männlich',
        height: 180,
        weight: 75,
        diet: 'vegetarisch',
      );
      expect(profile.isComplete, isFalse);
    });

    test('false when gender is null', () {
      const profile = UserProfile(
        birthYear: 1990,
        height: 180,
        weight: 75,
        diet: 'vegetarisch',
      );
      expect(profile.isComplete, isFalse);
    });

    test('false when height is null', () {
      const profile = UserProfile(
        birthYear: 1990,
        gender: 'männlich',
        weight: 75,
        diet: 'vegetarisch',
      );
      expect(profile.isComplete, isFalse);
    });

    test('false when weight is null', () {
      const profile = UserProfile(
        birthYear: 1990,
        gender: 'männlich',
        height: 180,
        diet: 'vegetarisch',
      );
      expect(profile.isComplete, isFalse);
    });

    test('false when diet is null', () {
      const profile = UserProfile(
        birthYear: 1990,
        gender: 'männlich',
        height: 180,
        weight: 75,
      );
      expect(profile.isComplete, isFalse);
    });

    test('false with default constructor (all null)', () {
      const profile = UserProfile();
      expect(profile.isComplete, isFalse);
    });
  });

  group('UserProfile health consent JSON', () {
    test('maps the snake_case consent columns', () {
      final profile = UserProfile.fromJson({
        'health_consent_at': '2026-11-22T09:30:00.000Z',
        'privacy_policy_version': '2026-11-22',
      });
      expect(profile.healthConsentAt, DateTime.utc(2026, 11, 22, 9, 30));
      expect(profile.privacyPolicyVersion, '2026-11-22');

      final json = profile.toJson();
      expect(json['health_consent_at'], '2026-11-22T09:30:00.000Z');
      expect(json['privacy_policy_version'], '2026-11-22');
    });

    test('consent columns default to null', () {
      final profile = UserProfile.fromJson(const {});
      expect(profile.healthConsentAt, isNull);
      expect(profile.privacyPolicyVersion, isNull);
    });
  });

  group('UserProfile.weeklyTipsEnabled', () {
    test('is false when the key is missing', () {
      expect(UserProfile.fromJson(const {}).weeklyTipsEnabled, isFalse);
    });

    test('reads weekly_tips_enabled', () {
      final profile = UserProfile.fromJson(const {'weekly_tips_enabled': true});
      expect(profile.weeklyTipsEnabled, isTrue);
    });
  });

  group('UserProfile daily review', () {
    test(
      'profile JSON without the new keys → 19:30 and false; with them → read',
      () {
        final plain = UserProfile.fromJson(const {});
        expect(plain.dailyReviewTime, '19:30');
        expect(plain.dailyReviewReminder, isFalse);

        final set = UserProfile.fromJson(const {
          'daily_review_time': '21:00',
          'daily_review_reminder': true,
        });
        expect(set.dailyReviewTime, '21:00');
        expect(set.dailyReviewReminder, isTrue);
        expect(set.toJson()['daily_review_time'], '21:00');
        expect(set.toJson()['daily_review_reminder'], isTrue);
      },
    );

    test(
      'withNotifications(true) keeps dailyReviewReminder false; withNotifications(false) clears true',
      () {
        const off = UserProfile(
          remindersEnabled: false,
          dailySummaryEnabled: false,
          pushEnabled: false,
        );
        expect(off.anyNotificationOn, isFalse);
        expect(off.withNotifications(true).dailyReviewReminder, isFalse);

        final onlyReview = off.copyWith(dailyReviewReminder: true);
        expect(onlyReview.anyNotificationOn, isTrue);
        expect(onlyReview.withNotifications(true).dailyReviewReminder, isTrue);
        final cleared = onlyReview.withNotifications(false);
        expect(cleared.dailyReviewReminder, isFalse);
        expect(cleared.anyNotificationOn, isFalse);
      },
    );
  });
}
