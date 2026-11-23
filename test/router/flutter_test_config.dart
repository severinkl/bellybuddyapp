import 'dart:async';

import 'package:belly_buddy/widgets/buddy/animated_buddy.dart';

/// Tests here reach screens with an animated Buddy (dashboard hero, welcome
/// screen) and use `pumpAndSettle`, which never settles while a Buddy ticks:
/// Buddies render without ticking. Tests that need ticking set
/// [AnimatedBuddy.tickerEnabled] back to true and restore it afterwards.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AnimatedBuddy.tickerEnabled = false;
  await testMain();
}
