import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/user_profile.dart';
import '../providers/core_providers.dart';
import '../repositories/profile_repository.dart';
import '../utils/logger.dart';

/// Profile state notifier
class ProfileNotifier extends Notifier<AsyncValue<UserProfile?>> {
  static const _log = AppLogger('ProfileProvider');
  bool _busy = false;

  /// The user whose profile the last fetch (or update) loaded; null before
  /// the first one and after [reset]. Tells the state of the signed-in user
  /// apart from one left over from before a sign-in (sign-out's `null`).
  String? get loadedFor => _loadedFor;
  String? _loadedFor;

  /// Only [setWeeklyTips] changes the weekly-tips switch here: a save holding
  /// an older profile keeps the switch as it stands, and so does a fetch that
  /// overlapped a switch (its read may predate the write). Kept for that: the
  /// switch's latest value and its user, the writes still on their way, and
  /// a count of switches.
  ({String userId, bool enabled})? _switched;
  int _switchWrites = 0;
  int _switches = 0;

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
    final overlapping = _switchWrites > 0;
    final switches = _switches;
    try {
      final userId = _resolveUserId();
      _loadedFor = userId;
      if (userId == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final profile = await ref
          .read(profileRepositoryProvider)
          .getProfile(userId);
      final switched = _switched;
      state = AsyncValue.data(
        (overlapping || _switches != switches) && switched?.userId == userId
            ? profile?.copyWith(weeklyTipsEnabled: switched!.enabled)
            : profile,
      );
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
    _loadedFor = userId;
    state = AsyncValue.data(_keepSwitch(profile.copyWith(userId: userId)));

    try {
      await ref.read(profileRepositoryProvider).updateProfile(userId, profile);
    } catch (e) {
      state = switch (previous) {
        AsyncData(:final value?) => AsyncValue.data(_keepSwitch(value)),
        _ => previous,
      };
      rethrow;
    }
  }

  /// Saves [change] applied to the latest loaded profile (not to one read
  /// earlier), through [updateProfile]; nothing while none is loaded.
  Future<void> updateWith(UserProfile Function(UserProfile) change) async {
    final latest = state.value;
    if (latest == null) return;
    await updateProfile(change(latest));
  }

  /// [profile] with the weekly-tips switch as it stands: the loaded
  /// profile's, else (mid-fetch) the one a switch still writing set.
  UserProfile _keepSwitch(UserProfile profile) {
    final switched = _switched;
    final enabled =
        state.value?.weeklyTipsEnabled ??
        (_switchWrites > 0 && switched?.userId == profile.userId
            ? switched!.enabled
            : null);
    return enabled == null
        ? profile
        : profile.copyWith(weeklyTipsEnabled: enabled);
  }

  /// Stores the user's health-data consent for the current privacy policy
  /// version and applies it to the loaded profile, which lifts the consent
  /// gate. Rethrows on failure so the caller can show an error.
  Future<void> acceptHealthConsent() async {
    final userId = _resolveUserId();
    if (userId == null) throw Exception('Not authenticated');

    _log.debug('recording health consent for $userId');
    final acceptedAt = await ref
        .read(profileRepositoryProvider)
        .acceptHealthConsent(userId);
    final profile = state.value;
    if (profile != null) {
      state = AsyncValue.data(
        profile.copyWith(
          healthConsentAt: acceptedAt,
          privacyPolicyVersion: AppConstants.privacyPolicyVersion,
        ),
      );
    } else {
      await fetchProfile();
    }
  }

  /// Switches the weekly tips on or off: optimistic, the switch reverted
  /// and rethrown on failure (e.g. a backend without the column). Touches
  /// nothing else: a profile write meanwhile stays.
  Future<void> setWeeklyTips(bool enabled) async {
    final profile = state.value;
    final userId = _resolveUserId();
    if (profile == null || userId == null) {
      throw StateError('setWeeklyTips needs a loaded profile');
    }
    final was = profile.weeklyTipsEnabled;
    _switched = (userId: userId, enabled: enabled);
    _switches++;
    _switchWrites++;
    state = AsyncValue.data(profile.copyWith(weeklyTipsEnabled: enabled));
    try {
      await ref.read(profileRepositoryProvider).setWeeklyTips(userId, enabled);
    } catch (e) {
      if (_switched?.userId == userId) {
        _switched = (userId: userId, enabled: was);
        if (state case AsyncData(:final value?)) {
          state = AsyncValue.data(value.copyWith(weeklyTipsEnabled: was));
        }
      }
      rethrow;
    } finally {
      _switchWrites--;
    }
  }

  void reset() {
    _loadedFor = null;
    _switched = null;
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

/// Whether the weekly tips are on; null while the profile is loading, failed
/// or missing.
final weeklyTipsEnabledProvider = Provider<bool?>(
  (ref) => ref.watch(profileProvider).value?.weeklyTipsEnabled,
);
