import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../utils/logger.dart';

const _log = AppLogger('ScreenAwake');

/// Keeps the screen from locking while on; tests record the calls.
abstract interface class ScreenAwake {
  Future<void> set(bool on);
}

/// [ScreenAwake] through `wakelock_plus`; the only user of the package.
class WakelockScreenAwake implements ScreenAwake {
  const WakelockScreenAwake();

  @override
  Future<void> set(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (e, st) {
      _log.error('Could not set the wake lock', e, st);
    }
  }
}

final screenAwakeProvider = Provider<ScreenAwake>(
  (_) => const WakelockScreenAwake(),
);
