import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_version_service.dart';
import '../utils/logger.dart';
import '../utils/semver.dart';
import 'app_config_provider.dart';

enum UpgradeDecision { ok, softNudge, hardGate }

const _log = AppLogger('UpgradeGate');

/// Installed app semver. Overridable in tests.
final currentVersionProvider = FutureProvider<String>((ref) {
  return ref.watch(appVersionServiceProvider).currentVersion();
});

/// Merges [appConfigProvider] and [currentVersionProvider] into a single
/// decision. On any failure (version lookup or config fetch) we log a warning
/// and fail open to keep the app usable for offline / flaky-network users.
final upgradeDecisionProvider = FutureProvider<UpgradeDecision>((ref) async {
  try {
    final version = await ref.watch(currentVersionProvider.future);
    final config = await ref.watch(appConfigProvider.future);
    if (compareSemver(version, config.minimum) < 0) {
      return UpgradeDecision.hardGate;
    }
    if (compareSemver(version, config.latest) < 0) {
      return UpgradeDecision.softNudge;
    }
    return UpgradeDecision.ok;
  } catch (e) {
    _log.warn('upgrade check failed, failing open: $e');
    return UpgradeDecision.ok;
  }
});

/// Sticky flag: true once [upgradeDecisionProvider] resolves to
/// [UpgradeDecision.hardGate]. It never goes back to false for the life of
/// the process. The router redirect sends every location to
/// `/upgrade-required` while it is set, so no navigation (notification
/// taps, pending routes, deep links) can leave the gate.
class HardGateActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void activate() => state = true;
}

final hardGateActiveProvider = NotifierProvider<HardGateActiveNotifier, bool>(
  HardGateActiveNotifier.new,
);

/// One-shot flag set true when the decision is [UpgradeDecision.softNudge].
/// The dashboard shows the "update available" dialog and clears the flag via
/// [SoftNudgePendingNotifier.consume], so the dialog appears exactly once.
class SoftNudgePendingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markPending() => state = true;

  /// Returns whether a nudge was pending and clears the flag.
  bool consume() {
    final pending = state;
    if (pending) state = false;
    return pending;
  }
}

final softNudgePendingProvider =
    NotifierProvider<SoftNudgePendingNotifier, bool>(
      SoftNudgePendingNotifier.new,
    );

/// Applies [upgradeDecisionProvider] to the gate flags whenever it resolves.
/// Call from the `build` of the app root (it uses [WidgetRef.listen]), so the
/// decision is handled even when the `app_config` fetch outlives the splash.
/// The app root is the decision's first listener, so the listener sees the
/// loading → data transition and no `fireImmediately` is needed.
void listenForUpgradeDecision(WidgetRef ref) {
  ref.listen<AsyncValue<UpgradeDecision>>(upgradeDecisionProvider, (_, next) {
    switch (next.value) {
      case UpgradeDecision.hardGate:
        _log.debug('installed version below minimum, activating hard gate');
        ref.read(hardGateActiveProvider.notifier).activate();
      case UpgradeDecision.softNudge:
        ref.read(softNudgePendingProvider.notifier).markPending();
      case UpgradeDecision.ok:
      case null:
        break;
    }
  });
}
