import 'package:flutter_test/flutter_test.dart';

/// Turns on the system's reduce-motion setting for this test (cleared again
/// when it ends).
void reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}
