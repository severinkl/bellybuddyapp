import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../utils/logger.dart';


/// Profile state notifier
class ProfileNotifier extends Notifier<AsyncValue<UserProfile?>> {
  static const _maxRetries = 3;
  static const _log = AppLogger('ProfileProvider');

  @override
  AsyncValue<UserProfile?> build() => const AsyncValue.loading();

  Future<void> fetchProfile() async {
    await _fetchWithRetry(0);
  }

  Future<void> _fetchWithRetry(int attempt) async {
    state = const AsyncValue.loading();
    try {
      final userId = SupabaseService.userId;
      _log.debug('fetchProfile: userId=$userId (attempt ${attempt + 1}/$_maxRetries)');
      if (userId == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final data = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      _log.debug('fetchProfile: data=$data');

      if (data == null) {
        state = const AsyncValue.data(null);
        return;
      }

      state = AsyncValue.data(UserProfile.fromJson(data));
    } catch (e, st) {
      _log.error('fetchProfile (attempt ${attempt + 1}/$_maxRetries)', e);
      if (attempt < _maxRetries - 1) {
        await Future.delayed(Duration(seconds: (attempt + 1) * 2));
        return _fetchWithRetry(attempt + 1);
      }
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createProfile(UserProfile profile) async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null) throw Exception('Not authenticated');

      final authMethod = AuthService.detectAuthMethod();
      final data = profile.copyWith(
        userId: userId,
        authMethod: authMethod,
      ).toJson();
      data['user_id'] = userId;
      // Remove null values to let DB defaults apply
      data.removeWhere((key, value) => value == null);

      _log.debug('creating profile for $userId');
      await SupabaseService.client
          .from('profiles')
          .upsert(data, onConflict: 'user_id');
      // Fetch the full profile from DB (includes DB-generated fields like id, created_at)
      await fetchProfile();
    } catch (e, st) {
      _log.error('createProfile', e);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateProfile(UserProfile profile) async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null) throw Exception('Not authenticated');

      final data = profile.toJson();
      data.remove('user_id');

      await SupabaseService.client
          .from('profiles')
          .update(data)
          .eq('user_id', userId);

      state = AsyncValue.data(profile.copyWith(userId: userId));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final profileProvider =
    NotifierProvider<ProfileNotifier, AsyncValue<UserProfile?>>(ProfileNotifier.new);

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
