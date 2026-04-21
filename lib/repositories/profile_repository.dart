import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';

class ProfileRepository {
  final ProfileService _profileService;
  final AuthService _authService;
  static const _log = AppLogger('ProfileRepository');

  ProfileRepository(this._profileService, this._authService);

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
    // sending an explicit value suppresses the DB DEFAULT.
    data.remove('meal_reminder_times');
    data.remove('mood_reminder_times');
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
    await _profileService.update(userId, data);
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
