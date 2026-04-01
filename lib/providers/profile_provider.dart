import 'package:belly_buddy/repositories/auth_repository.dart';
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

  /// Falls back to the auth repository if the reactive provider has no value yet.
  String? _resolveUserId() =>
      ref.read(currentUserIdProvider) ??
      ref.read(authRepositoryProvider).currentUser?.id;

  Future<void> fetchProfile() async {
    if (_busy) {
      _log.debug('fetchProfile skipped — busy');
      return;
    }
    state = const AsyncValue.loading();
    try {
      final userId = _resolveUserId();
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
      final userId = _resolveUserId();
      if (userId == null) throw Exception('Not authenticated');

      _log.debug('creating profile for $userId');
      await ref.read(profileRepositoryProvider).createProfile(userId, profile);
      _busy = false;
      await fetchProfile();
    } catch (e, st) {
      _log.error('createProfile', e);
      state = AsyncValue.error(e, st);
      rethrow;
    } finally {
      _busy = false;
    }
  }

  Future<void> updateProfile(UserProfile profile) async {
    final previous = state;
    final userId = _resolveUserId();
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
