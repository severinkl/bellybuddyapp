import 'dart:async';

import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/widgets/buddy/animated_buddy.dart';

/// The Ich tab shows an animated Buddy and the tests use `pumpAndSettle`,
/// which never settles while a Buddy ticks: Buddies render without ticking
/// (and the care ring's glow, should a test reach Home, holds still).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AnimatedBuddy.tickerEnabled = false;
  CareRing.pulseEnabled = false;
  await testMain();
}
