import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/widgets/buddy/animated_buddy.dart';
import 'package:belly_buddy/widgets/buddy/streak_flame.dart';

/// Holds the app's never-ending ambient animations still: Buddies render
/// without ticking, the care ring's glow does not pulse and streak flames
/// neither wobble, breathe nor spark, so `pumpAndSettle` settles on any
/// screen that shows them.
///
/// The root `flutter_test_config.dart` calls this before every test file.
/// Tests that need ticking call [tickBuddiesInTests]; one that needs the
/// pulse or the flame's motion sets [CareRing.pulseEnabled] or
/// [StreakFlame.ambientEnabled] back to true and calls this in a
/// tear-down.
void disableAmbientAnimationsForTests() {
  AnimatedBuddy.tickerEnabled = false;
  CareRing.pulseEnabled = false;
  StreakFlame.ambientEnabled = false;
}

/// Lets the Buddies of every test in the enclosing group (or file) tick:
/// ticking on before each test, everything still again after it.
void tickBuddiesInTests() {
  setUp(() => AnimatedBuddy.tickerEnabled = true);
  tearDown(disableAmbientAnimationsForTests);
}
