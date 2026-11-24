import 'package:material_ui/material_ui.dart';

/// Sends the app to the background and back, as iOS does: resumed →
/// inactive → hidden, then hidden → inactive → resumed. What follows
/// [appForegroundProvider] hears of it (onShow), and so does every
/// [AppLifecycleListener]'s onResume.
void returnFromBackground() {
  final binding = WidgetsBinding.instance;
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    binding.handleAppLifecycleStateChanged(state);
  }
}

/// A blip to inactive and back without leaving the app (Control Center, a
/// Face ID prompt): onResume, but no return from the background.
void inactiveBlip() => WidgetsBinding.instance
  ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
  ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
