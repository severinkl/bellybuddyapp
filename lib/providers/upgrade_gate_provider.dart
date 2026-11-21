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

/// One-shot flag flipped true by the splash when the decision is
/// [UpgradeDecision.softNudge]. The dashboard reads this on first frame,
/// shows the dialog, then resets it to false via [SoftNudgePendingNotifier.set].
class SoftNudgePendingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: avoid_positional_boolean_parameters
  void set(bool value) => state = value;
}

final softNudgePendingProvider =
    NotifierProvider<SoftNudgePendingNotifier, bool>(
      SoftNudgePendingNotifier.new,
    );
