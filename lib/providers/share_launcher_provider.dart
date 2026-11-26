import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the system share sheet with a text. A provider so tests can
/// replace the platform call.
typedef ShareLauncher = Future<void> Function(String text);

final shareLauncherProvider = Provider<ShareLauncher>(
  (ref) =>
      (text) => SharePlus.instance.share(ShareParams(text: text)),
);
