import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/widgets/buddy/animated_buddy.dart';

/// Holds the app's never-ending ambient animations still: Buddies render
/// without ticking and the care ring's glow does not pulse, so
/// `pumpAndSettle` settles on any screen that shows them.
///
/// The root `flutter_test_config.dart` calls this before every test file.
/// Tests that need ticking call [tickBuddiesInTests]; one that needs the
/// pulse sets [CareRing.pulseEnabled] back to true and calls this in a
/// tear-down.
void disableAmbientAnimationsForTests() {
  AnimatedBuddy.tickerEnabled = false;
  CareRing.pulseEnabled = false;
}

/// Lets the Buddies of every test in the enclosing group (or file) tick:
/// ticking on before each test, everything still again after it.
void tickBuddiesInTests() {
  setUp(() => AnimatedBuddy.tickerEnabled = true);
  tearDown(disableAmbientAnimationsForTests);
}
