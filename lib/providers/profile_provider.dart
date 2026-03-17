import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';

/// Profile state notifier
class ProfileNotifier extends Notifier<AsyncValue<UserProfile?>> {
  static const _log = AppLogger('ProfileProvider');

  @override
  AsyncValue<UserProfile?> build() => const AsyncValue.loading();

  Future<void> fetchProfile() async {
    state = const AsyncValue.loading();
    try {
      final userId = SupabaseService.userId;
      if (userId == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final profile = await retryAsync(
        () => ProfileService.fetchByUserId(userId),
        log: _log,
        label: 'fetchProfile',
      );
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createProfile(UserProfile profile) async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null) throw Exception('Not authenticated');

      final authMethod = AuthService.detectAuthMethod();
      final data = profile
          .copyWith(userId: userId, authMethod: authMethod)
          .toJson();
      data['user_id'] = userId;
      // Remove null values to let DB defaults apply
      data.removeWhere((key, value) => value == null);

      _log.debug('creating profile for $userId');
      await ProfileService.upsert(data);
      // Fetch the full profile from DB (includes DB-generated fields like id, created_at)
      await fetchProfile();
    } catch (e, st) {
      _log.error('createProfile', e);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateProfile(UserProfile profile) async {
    final previous = state;
    final userId = SupabaseService.userId;
    if (userId == null) throw Exception('Not authenticated');

    // Optimistic update — revert on failure
    state = AsyncValue.data(profile.copyWith(userId: userId));

    try {
      final data = profile.toJson();
      data.remove('user_id');

      await ProfileService.update(userId, data);
    } catch (e) {
      state = previous;
      rethrow;
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final profileProvider =
    NotifierProvider<ProfileNotifier, AsyncValue<UserProfile?>>(
      ProfileNotifier.new,
    );

/// Whether a profile row exists (regardless of completeness)
final hasProfileProvider = Provider<bool>((ref) {
  final profileState = ref.watch(profileProvider);
  return profileState.whenOrNull(data: (profile) => profile != null) ?? false;
});

/// Whether registration is complete
final hasCompletedRegistrationProvider = Provider<bool>((ref) {
  final profileState = ref.watch(profileProvider);
  return profileState.whenOrNull(
        data: (profile) => profile?.isComplete ?? false,
      ) ??
      false;
});
