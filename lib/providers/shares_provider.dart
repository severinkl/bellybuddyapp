import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/data_share.dart';
import '../services/share_secrets_store.dart';
import '../services/share_service.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';
import 'core_providers.dart';

/// The user's shares, newest first. Empty while nobody is signed in.
class SharesNotifier extends AsyncNotifier<List<DataShare>> {
  static const _log = AppLogger('SharesProvider');

  @override
  Future<List<DataShare>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    return ref.read(shareServiceProvider).list();
  }

  /// Creates a share, keeps its link and code on this device and the name
  /// for the next one, then reloads the list. Throws what the service throws.
  Future<CreatedShare> create(NewShare share) async {
    final created = await ref.read(shareServiceProvider).create(share);
    final store = ref.read(shareSecretsStoreProvider);
    // The share exists on the server: a local write failing must not turn
    // that into a failure (the user would create a second one).
    await Future.wait([
      _bestEffort(
        'keeping the new share on this device',
        () => store.save(
          created.id,
          ShareSecret(link: created.link, code: created.code),
        ),
      ),
      _bestEffort(
        'remembering the display name',
        () => store.rememberDisplayName(share.displayName),
      ),
    ]);
    ref.invalidate(shareSecretProvider(created.id));
    // A failing reload keeps the list shown; the create itself worked.
    await refresh();
    return created;
  }

  /// Ends a share, drops its secret from this device and reloads the list.
  /// A failing call throws and leaves state and secret as they were.
  Future<void> end(String id) async {
    await ref.read(shareServiceProvider).end(id);
    await _bestEffort(
      'dropping the secret of an ended share',
      () => ref.read(shareSecretsStoreProvider).remove(id),
    );
    ref.invalidate(shareSecretProvider(id));
    // A failing reload keeps the list shown; the end itself worked.
    await refresh();
  }

  /// Loads the list again, keeping what is shown while it runs, and tells
  /// whether that worked. A failure keeps the list shown; with nothing shown
  /// yet it becomes the error. An answer that arrives after the signed-in
  /// user changed is dropped: it belongs to the previous account.
  /// The same goes for an answer overtaken by a later refresh.
  Future<bool> refresh() async {
    final userId = ref.read(currentUserIdProvider);
    final request = ++_latestRequest;
    // A load still on its way (the first, or one for a new account) would
    // land after this answer and undo it: wait for it first.
    if (state.isLoading) {
      try {
        await future;
      } catch (_) {
        // Its error is the state already; this load may still work.
      }
    }
    bool stale() =>
        request != _latestRequest ||
        !ref.mounted ||
        ref.read(currentUserIdProvider) != userId;
    try {
      final shares = await ref.read(shareServiceProvider).list();
      if (stale()) return true;
      state = AsyncData(shares);
      return true;
    } catch (e, st) {
      _log.error('refreshing the shares failed', e, st);
      if (stale()) return true;
      if (!state.hasValue) state = AsyncError(e, st);
      return false;
    }
  }

  /// The newest [refresh]; only its answer is written.
  int _latestRequest = 0;

  /// A local write after a server success: logged (never with secrets) and
  /// carried on.
  Future<void> _bestEffort(String what, Future<void> Function() write) async {
    try {
      await write();
    } catch (e, st) {
      _log.error('$what failed', e, st);
    }
  }
}

/// No automatic rebuild retries: a failed load shows the error view with
/// its own „Erneut versuchen" right away.
final sharesProvider = AsyncNotifierProvider<SharesNotifier, List<DataShare>>(
  SharesNotifier.new,
  retry: noRetry,
);

/// The link and code of a share, when this device still has them.
final shareSecretProvider = FutureProvider.autoDispose
    .family<ShareSecret?, String>(
      (ref, id) => ref.read(shareSecretsStoreProvider).read(id),
    );

/// Whether the Ich row shows its „Neu" badge: until it was tapped once.
class ShareRowBadgeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(AppConstants.keyShareRowTapped) ?? false);
  }

  Future<void> markTapped() async {
    state = const AsyncData(false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyShareRowTapped, true);
  }
}

final shareRowBadgeProvider =
    AsyncNotifierProvider<ShareRowBadgeNotifier, bool>(
      ShareRowBadgeNotifier.new,
    );

/// The share just created, until the list screen has shown its link and
/// code once. Holds a secret: cleared as soon as it is taken.
class JustCreatedShareNotifier extends Notifier<ShareSecret?> {
  /// Watches the user: a pending secret never reaches the next account
  /// after a sign-out or an account deletion.
  @override
  ShareSecret? build() {
    ref.watch(currentUserIdProvider);
    return null;
  }

  void set(ShareSecret secret) => state = secret;

  /// The held secret, which is then forgotten.
  ShareSecret? take() {
    final secret = state;
    state = null;
    return secret;
  }
}

final justCreatedShareProvider =
    NotifierProvider<JustCreatedShareNotifier, ShareSecret?>(
      JustCreatedShareNotifier.new,
    );
