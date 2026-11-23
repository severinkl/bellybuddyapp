import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/dashboard/widgets/care_ring.dart';
import 'package:belly_buddy/widgets/buddy/animated_buddy.dart';

import '../../integration_test/helpers/test_app.dart';
import '../helpers/ambient_animations.dart';

void main() {
  test('buildTestApp holds the Buddies and the care ring\'s glow still, so '
      'pumpAndSettle settles on the dashboard', () {
    AnimatedBuddy.tickerEnabled = true;
    CareRing.pulseEnabled = true;
    addTearDown(disableAmbientAnimationsForTests);

    buildTestApp();

    expect(AnimatedBuddy.tickerEnabled, isFalse);
    expect(CareRing.pulseEnabled, isFalse);
  });
}
