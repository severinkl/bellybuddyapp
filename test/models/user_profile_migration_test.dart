import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/models/user_profile.dart';

void main() {
  group('UserProfile new fields', () {
    test('defaults are correct', () {
      const profile = UserProfile();
      expect(profile.remindersEnabled, isTrue);
      expect(profile.dailySummaryEnabled, isTrue);
      expect(profile.pushEnabled, isFalse);
      expect(profile.dailySummaryTime, '20:00');
      expect(profile.fcmToken, isNull);
      expect(profile.lastInactivityNudge, isNull);
      expect(profile.reminderTimes, ['18:00']);
    });

    test('fromJson with legacy int reminderTimes', () {
      final json = {
        'reminder_times': [7, 12, 18],
      };
      final profile = UserProfile.fromJson(json);
      expect(profile.reminderTimes, ['07:00', '12:00', '18:00']);
    });

    test('fromJson with new string reminderTimes', () {
      final json = {
        'reminder_times': ['07:30', '12:00', '18:30'],
      };
      final profile = UserProfile.fromJson(json);
      expect(profile.reminderTimes, ['07:30', '12:00', '18:30']);
    });

    test('fromJson with new fields', () {
      final json = {
        'reminders_enabled': false,
        'daily_summary_enabled': true,
        'push_enabled': true,
        'daily_summary_time': '21:00',
        'fcm_token': 'abc123',
      };
      final profile = UserProfile.fromJson(json);
      expect(profile.remindersEnabled, isFalse);
      expect(profile.dailySummaryEnabled, isTrue);
      expect(profile.pushEnabled, isTrue);
      expect(profile.dailySummaryTime, '21:00');
      expect(profile.fcmToken, 'abc123');
    });
  });
}
