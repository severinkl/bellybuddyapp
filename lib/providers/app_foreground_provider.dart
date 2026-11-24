import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Counts the app's returns to the foreground: a real return from the
/// background (onShow: hidden → inactive), not a blip to inactive and back
/// (Control Center, a Face ID prompt). Whatever follows the foreground
/// listens to it (the day, the tips and Alternativen), all through this one
/// [AppLifecycleListener].
class AppForegroundNotifier extends Notifier<int> {
  @override
  int build() {
    final lifecycle = AppLifecycleListener(onShow: () => state++);
    ref.onDispose(lifecycle.dispose);
    return 0;
  }
}

final appForegroundProvider = NotifierProvider<AppForegroundNotifier, int>(
  AppForegroundNotifier.new,
);
