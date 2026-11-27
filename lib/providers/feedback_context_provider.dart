import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feedback.dart';
import '../utils/logger.dart';
import 'upgrade_gate_provider.dart';

const _log = AppLogger('FeedbackContext');
const _unknown = 'unbekannt';

/// Reads the OS version (`18.1`, `14`) from the device. Tests replace it.
final osVersionReaderProvider = Provider<Future<String> Function()>(
  (ref) => () async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isIOS) return (await plugin.iosInfo).systemVersion;
    return (await plugin.androidInfo).version.release;
  },
);

/// App version and OS sent along with feedback; a value that cannot be read
/// is `unbekannt`.
final feedbackContextProvider = FutureProvider<FeedbackContext>((ref) async {
  final reader = ref.watch(osVersionReaderProvider);
  Future<String> read(Future<String> Function() f, String what) async {
    try {
      final value = await f();
      return value.isEmpty ? _unknown : value;
    } catch (_) {
      _log.warn('$what unreadable');
      return _unknown;
    }
  }

  final version = await read(
    () => ref.read(currentVersionProvider.future),
    'version',
  );
  final os = await read(reader, 'os version');
  return FeedbackContext(
    appVersion: version,
    platform: Platform.isIOS ? 'ios' : 'android',
    osVersion: os,
  );
});
