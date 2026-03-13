import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';


/// Profile state notifier
class ProfileNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  ProfileNotifier() : super(const AsyncValue.loading());

  Future<void> fetchProfile() async {
    state = const AsyncValue.loading();
    try {
      final userId = SupabaseService.userId;
      if (userId == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final data = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data == null) {
        state = const AsyncValue.data(null);
        return;
      }

      state = AsyncValue.data(UserProfile.fromJson(data));
    } catch (e, st) {
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

      await SupabaseService.client.from('profiles').insert(data);
      state = AsyncValue.data(profile.copyWith(userId: userId, authMethod: authMethod));
    } catch (e, st) {
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
    StateNotifierProvider<ProfileNotifier, AsyncValue<UserProfile?>>((ref) {
  return ProfileNotifier();
});

/// Whether registration is complete
final hasCompletedRegistrationProvider = Provider<bool>((ref) {
  final profileState = ref.watch(profileProvider);
  return profileState.whenOrNull(
        data: (profile) => profile?.isComplete ?? false,
      ) ??
      false;
});
