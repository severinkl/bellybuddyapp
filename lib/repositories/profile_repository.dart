import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import '../config/constants.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';

class ProfileRepository {
  final ProfileService _profileService;
  final AuthService _authService;
  static const _log = AppLogger('ProfileRepository');

  ProfileRepository(
    this._profileService,
    this._authService, {
    String? Function()? deviceTimezone,
  }) : _deviceTimezone = deviceTimezone ?? _localTimezone;

  /// The device's IANA time zone, written with every create and update so
  /// the profile follows the device; null while unknown.
  final String? Function() _deviceTimezone;

  /// The zone `LocalNotificationService.initialize` set from
  /// flutter_timezone (the reminders use it too). Before that the package
  /// has none, or its default UTC, which says nothing about the device.
  static String? _localTimezone() {
    try {
      final name = tz.local.name;
      return name == 'UTC' ? null : name;
    } catch (_) {
      return null;
    }
  }

  /// Puts the device's time zone into [data], or leaves the column alone
  /// while it is unknown.
  void _applyDeviceTimezone(Map<String, dynamic> data) {
    final timezone = _deviceTimezone();
    if (timezone == null) {
      data.remove('timezone');
    } else {
      data['timezone'] = timezone;
    }
  }

  Future<UserProfile?> getProfile(String userId) async {
    return retryAsync(
      () => _profileService.fetchByUserId(userId),
      log: _log,
      label: 'fetchProfile',
    );
  }

  Future<void> createProfile(String userId, UserProfile profile) async {
    final authMethod = _authService.detectAuthMethod();
    final data = profile
        .copyWith(userId: userId, authMethod: authMethod)
        .toJson();
    data['user_id'] = userId;
    // Let Postgres apply the column DEFAULTs for reminder times. The Freezed
    // model has defaults too, but they don't match the DB defaults, and
    // sending an explicit value suppresses the DB DEFAULT. This strips
    // unconditionally — if registration ever collects user-picked times,
    // guard the removes or those inputs will be dropped silently.
    // Weekly tips are written only by setWeeklyTips; the column may not
    // exist yet (migration 0009).
    data.remove('weekly_tips_enabled');
    data.remove('meal_reminder_times');
    data.remove('mood_reminder_times');
    // Not the model's default (Europe/Berlin): the device's own zone.
    _applyDeviceTimezone(data);
    data.removeWhere((key, value) => value == null);
    await _profileService.upsert(data);
  }

  Future<void> updateProfile(String userId, UserProfile profile) async {
    final data = profile.toJson();
    data.remove('user_id');
    // fcm_token is managed separately by PushNotificationService
    data.remove('fcm_token');
    // tutorial_seen_at is managed by TutorialNotifier.markSeen — a stale
    // UserProfile (captured before markSeen fired) must not overwrite it.
    data.remove('tutorial_seen_at');
    // The health consent is written only by acceptHealthConsent — a stale
    // UserProfile must neither clear nor forge it.
    data.remove('health_consent_at');
    data.remove('privacy_policy_version');
    // Written only by setWeeklyTips: a stale profile must not flip the
    // opt-in, and a backend without migration 0009 must still accept this.
    data.remove('weekly_tips_enabled');
    _applyDeviceTimezone(data);
    await _profileService.update(userId, data);
  }

  /// Records the user's explicit consent (GDPR Art. 9) to the processing of
  /// their health data under the current privacy policy version. Returns the
  /// stored timestamp (UTC).
  Future<DateTime> acceptHealthConsent(String userId, {DateTime? now}) async {
    final acceptedAt = (now ?? DateTime.now()).toUtc();
    await _profileService.update(userId, {
      'health_consent_at': acceptedAt.toIso8601String(),
      'privacy_policy_version': AppConstants.privacyPolicyVersion,
    });
    return acceptedAt;
  }

  /// Switches the weekly AI tips on or off. Touches only that column.
  Future<void> setWeeklyTips(String userId, bool enabled) async {
    await _profileService.update(userId, {'weekly_tips_enabled': enabled});
  }

  Future<void> updateTutorialSeenAt(String userId, DateTime? value) async {
    await _profileService.update(userId, {
      'tutorial_seen_at': value?.toIso8601String(),
    });
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    ref.watch(profileServiceProvider),
    ref.watch(authServiceProvider),
  ),
);
