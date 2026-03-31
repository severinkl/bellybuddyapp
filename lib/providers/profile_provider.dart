import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../providers/core_providers.dart';
import '../repositories/profile_repository.dart';
import '../utils/logger.dart';

/// Profile state notifier
class ProfileNotifier extends Notifier<AsyncValue<UserProfile?>> {
  static const _log = AppLogger('ProfileProvider');
  bool _busy = false;

  @override
  AsyncValue<UserProfile?> build() => const AsyncValue.loading();

  Future<void> fetchProfile() async {
    if (_busy) return; // Already creating/fetching — skip duplicate call
    state = const AsyncValue.loading();
    try {
      final userId =
          ref.read(currentUserIdProvider) ??
          ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (userId == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final profile = await ref
          .read(profileRepositoryProvider)
          .getProfile(userId);
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createProfile(UserProfile profile) async {
    _busy = true;
    try {
      // Use currentUserIdProvider if available, otherwise fall back to reading
      // directly from the Supabase client. After sign-up the auth stream may
      // not have propagated yet, but the client already has the session.
      final userId =
          ref.read(currentUserIdProvider) ??
          ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      _log.debug('creating profile for $userId');
      await ref.read(profileRepositoryProvider).createProfile(userId, profile);
      // Fetch the full profile from DB (includes DB-generated fields like id, created_at)
      _busy = false;
      await fetchProfile();
    } catch (e, st) {
      _busy = false;
      _log.error('createProfile', e);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateProfile(UserProfile profile) async {
    final previous = state;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) throw Exception('Not authenticated');

    // Optimistic update — revert on failure
    state = AsyncValue.data(profile.copyWith(userId: userId));

    try {
      await ref.read(profileRepositoryProvider).updateProfile(userId, profile);
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
