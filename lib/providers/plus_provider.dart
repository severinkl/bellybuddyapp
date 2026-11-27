import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/plus_status.dart';
import '../services/edge_function_service.dart';
import '../services/purchases/purchases_gateway.dart';
import '../utils/logger.dart';
import '../utils/retry_helper.dart';
import 'app_config_provider.dart';
import 'auth_provider.dart';

const _log = AppLogger('Plus');

/// The Belly Buddy Plus switch (`app_config.paywall_enabled`). While the
/// config loads or cannot be read the switch counts as off (decision 11).
final paywallEnabledProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).value?.paywallEnabled ?? false,
);

/// The signed-in user's Plus status from the purchases SDK.
///
/// Switch off, nobody signed in or no SDK key → [PlusStatus.none] without any
/// SDK call (no anonymous customers, decision 13). The first user configures
/// the SDK with their Supabase id, a later different user switches with
/// `logIn`; sign-out calls nothing (R12: `logOut` would create an anonymous
/// customer) — the next user's `logIn` switches the identity. Only a
/// successful account deletion logs the SDK out ([forgetDevice], R18). A
/// result for a user who is no longer signed in lands nowhere.
class PlusNotifier extends AsyncNotifier<PlusStatus> {
  /// The SDK has been configured in this app run (only once ever).
  bool _configured = false;

  /// User the SDK is identified as; null while unknown (a failed switch).
  String? _identity;

  /// Serialises configure/logIn: never two at once.
  Future<void> _identifying = Future.value();

  /// User the last build ran for, to blank a previous user's status.
  String? _builtFor;

  @override
  Future<PlusStatus> build() async {
    final ref = this.ref;
    final enabled = ref.watch(paywallEnabledProvider);
    final userId = ref.watch(currentUserIdProvider);
    final gateway = ref.watch(purchasesGatewayProvider);

    // Never show the previous user's status while the next one loads:
    // Riverpod carries the previous value into the loading state, so replace
    // it with none first (still loading, so access stays open).
    if (_builtFor != userId) {
      _builtFor = userId;
      state = const AsyncData(PlusStatus.none);
      state = const AsyncLoading();
    }

    if (!enabled || userId == null || !gateway.available) {
      return PlusStatus.none;
    }

    if (!await _identify(ref, gateway, userId)) return PlusStatus.none;
    // A rebuild may land between the identify and here: never subscribe for
    // a gone build (onDispose would throw on an unmounted ref).
    if (!ref.isCurrentUser(userId)) return PlusStatus.none;

    PlusStatus? pushed;
    final sub = gateway.statusChanges.listen((status) {
      if (ref.isCurrentUser(userId) && _identity == userId) {
        pushed = status;
        state = AsyncData(status);
      }
    });
    ref.onDispose(sub.cancel);

    final status = await gateway.status();
    // A stale build's answer is dropped; the newer build owns the state.
    if (!ref.isCurrentUser(userId)) return PlusStatus.none;
    // A push that arrived while status() ran is newer than its answer.
    return pushed ?? status;
  }

  /// Makes the SDK identify as [userId] (configure first time, else logIn),
  /// one call at a time. False when [userId] stopped being current meanwhile.
  /// Throws what the gateway throws.
  Future<bool> _identify(Ref ref, PurchasesGateway gateway, String userId) {
    final run = _identifying.then((_) async {
      if (!ref.isCurrentUser(userId)) return false;
      if (_identity == userId) return true;
      _identity = null;
      if (_configured) {
        await gateway.logIn(userId);
      } else {
        await gateway.configure(userId);
        _configured = true;
      }
      _identity = userId;
      return ref.isCurrentUser(userId);
    });
    _identifying = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  /// After a successful account deletion: logs the SDK out (R18), so its
  /// foreground refresh (get-or-create) cannot re-create the deleted user's
  /// customer. Only when the SDK was configured in this run; queued behind a
  /// running configure/logIn. A failure is logged and ignored.
  Future<void> forgetDevice() {
    final gateway = ref.read(purchasesGatewayProvider);
    final run = _identifying.then((_) async {
      if (!_configured) return;
      _identity = null;
      try {
        await gateway.logOut();
        _log.debug('logOut: done');
      } catch (e) {
        _log.warn('logOut: failed (${e.runtimeType})');
      }
    });
    _identifying = run;
    return run;
  }

  /// Ensures the SDK is identified as the signed-in user (for the offer).
  /// False when the switch is off, nobody is signed in, there is no SDK key
  /// or the user changed meanwhile.
  Future<bool> identifyCurrent(Ref caller) async {
    final userId = caller.read(currentUserIdProvider);
    final gateway = caller.read(purchasesGatewayProvider);
    if (!caller.read(paywallEnabledProvider) ||
        userId == null ||
        !gateway.available) {
      return false;
    }
    return _identify(caller, gateway, userId);
  }

  /// Buys [offer] for the signed-in user.
  Future<PurchaseOutcome> purchase(PlusOffer offer) =>
      _settle('purchase', (g) => g.purchase(offer));

  /// Restores earlier purchases for the signed-in user.
  Future<PurchaseOutcome> restore() => _settle('restore', (g) => g.restore());

  /// [userId] is still signed in. Reads the notifier's current ref: the
  /// ref of an earlier build unmounts on any rebuild, even for the same user.
  bool _stillSignedIn(String userId) {
    final ref = this.ref;
    return ref.mounted && ref.read(currentUserIdProvider) == userId;
  }

  /// Runs a purchase or restore for the signed-in user.
  ///
  /// When the user changed while the store sheet was open, a [PurchaseDone]
  /// belongs to the previous user: it is neither applied nor synced (the
  /// webhook records it for that user) and the caller gets
  /// [PurchaseCancelled], so the new user's paywall stays as it was instead
  /// of welcoming them to Plus they don't have.
  Future<PurchaseOutcome> _settle(
    String what,
    Future<PurchaseOutcome> Function(PurchasesGateway) run,
  ) async {
    final userId = ref.read(currentUserIdProvider);
    final gateway = ref.read(purchasesGatewayProvider);
    if (!ref.read(paywallEnabledProvider) ||
        userId == null ||
        !gateway.available) {
      return const PurchaseFailed();
    }
    await _identifying;
    if (_identity != userId || !_stillSignedIn(userId)) {
      _log.warn('$what: not identified');
      return const PurchaseFailed();
    }

    final PurchaseOutcome outcome;
    try {
      outcome = await run(gateway);
    } catch (e) {
      _log.warn('$what: failed (${e.runtimeType})');
      return const PurchaseFailed();
    }
    if (outcome is! PurchaseDone) return outcome;
    if (!_stillSignedIn(userId)) {
      _log.warn('$what: user changed');
      return const PurchaseCancelled();
    }

    state = AsyncData(outcome.status);
    await _sync();
    return outcome;
  }

  /// Tells core to look the entitlement up now (best effort: the webhook and
  /// the server's own lookup catch up otherwise).
  Future<void> _sync() async {
    try {
      await ref.read(edgeFunctionServiceProvider).invoke('plus-sync');
      _log.debug('plus-sync: done');
    } catch (_) {
      _log.warn('plus-sync: failed');
    }
  }
}

/// Not autoDispose: the SDK is configured once per app run.
final plusProvider = AsyncNotifierProvider<PlusNotifier, PlusStatus>(
  PlusNotifier.new,
  retry: noRetry,
);

/// The store's monthly offer for the signed-in user; null with the switch
/// off, nobody signed in, no SDK key, or no offer in the store.
final plusOfferProvider = FutureProvider.autoDispose<PlusOffer?>((ref) async {
  final enabled = ref.watch(paywallEnabledProvider);
  final userId = ref.watch(currentUserIdProvider);
  final gateway = ref.watch(purchasesGatewayProvider);
  if (!enabled || userId == null || !gateway.available) return null;

  if (!await ref.read(plusProvider.notifier).identifyCurrent(ref)) return null;
  final offer = await gateway.offer();
  return ref.isCurrentUser(userId) ? offer : null;
}, retry: noRetry);

enum PlusAccess { open, locked }

/// Whether Plus features are usable — every lock in the UI reads only this.
/// Switch off, nobody signed in (nothing to lock), no SDK key in this build
/// (nothing can be bought, R14), status unknown (loading, error) or
/// trial/active → open; none/lapsed → locked.
final plusAccessProvider = Provider<PlusAccess>((ref) {
  if (!ref.watch(paywallEnabledProvider)) return PlusAccess.open;
  if (ref.watch(currentUserIdProvider) == null) return PlusAccess.open;
  if (!ref.watch(purchasesGatewayProvider).available) return PlusAccess.open;
  final plus = ref.watch(plusProvider);
  if (plus.isLoading || plus.hasError) return PlusAccess.open;
  final status = plus.value;
  if (status == null || status.granted) return PlusAccess.open;
  return PlusAccess.locked;
});
