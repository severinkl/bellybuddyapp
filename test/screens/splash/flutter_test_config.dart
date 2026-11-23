import 'dart:async';

import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/widgets/buddy/animated_buddy.dart';

/// Tests here reach screens with an animated Buddy (dashboard hero, welcome
/// screen) and use `pumpAndSettle`, which never settles while a Buddy ticks
/// or the care ring's glow pulses: Buddies render without ticking and the
/// glow holds still. Tests that need ticking set
/// [AnimatedBuddy.tickerEnabled] back to true and restore it afterwards.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AnimatedBuddy.tickerEnabled = false;
  CareRing.pulseEnabled = false;
  await testMain();
}
