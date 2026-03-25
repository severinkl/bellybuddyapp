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
    data.removeWhere((key, value) => value == null);
    await _profileService.upsert(data);
  }

  Future<void> updateProfile(String userId, UserProfile profile) async {
    final data = profile.toJson();
    data.remove('user_id');
    await _profileService.update(userId, data);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    ref.watch(profileServiceProvider),
    ref.watch(authServiceProvider),
  ),
);
