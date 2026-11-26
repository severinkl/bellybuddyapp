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
    await store.save(
      created.id,
      ShareSecret(link: created.link, code: created.code),
    );
    await store.rememberDisplayName(share.displayName);
    ref.invalidate(shareSecretProvider(created.id));
    await _reload();
    return created;
  }

  /// Ends a share, drops its secret from this device and reloads the list.
  /// A failing call throws and leaves state and secret as they were.
  Future<void> end(String id) async {
    await ref.read(shareServiceProvider).end(id);
    await ref.read(shareSecretsStoreProvider).remove(id);
    ref.invalidate(shareSecretProvider(id));
    await _reload();
  }

  /// A failing reload keeps the list shown; the call that led here worked.
  Future<void> _reload() async {
    try {
      state = AsyncData(await ref.read(shareServiceProvider).list());
    } catch (e, st) {
      _log.error('reloading the shares failed', e, st);
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
  @override
  ShareSecret? build() => null;

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
