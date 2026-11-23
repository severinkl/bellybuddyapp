import 'dart:async';

import 'package:belly_buddy/widgets/buddy/animated_buddy.dart';

/// The registration wizard hosts an animated Buddy and its tests use
/// `pumpAndSettle`, which never settles while a Buddy ticks: Buddies render
/// without ticking. Reaction tests read the wizard's controller directly
/// (mood, action, bubble), which works without ticking; tests that need
/// ticking set [AnimatedBuddy.tickerEnabled] back to true and restore it.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AnimatedBuddy.tickerEnabled = false;
  await testMain();
}
