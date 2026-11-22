import 'package:belly_buddy/screens/welcome/welcome_screen.dart';
import 'package:flutter_test/flutter_test.dart';

// The welcome screen's animated Buddy ticks every frame, so `pumpAndSettle`
// never settles while it is on screen: these helpers pump in steps instead.
// Once the app has navigated away from it, `pumpAndSettle` works again.

/// Pumps in [step]s until [finder] matches; fails after [timeout].
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
  Duration step = const Duration(milliseconds: 100),
}) async {
  final steps = timeout.inMicroseconds ~/ step.inMicroseconds;
  for (var i = 0; i < steps && finder.evaluate().isEmpty; i++) {
    await tester.pump(step);
  }
  expect(finder, findsWidgets, reason: 'not shown within $timeout');
}

/// Waits until the welcome screen with its sleeping Buddy can be tapped (the
/// app's splash overlay is gone). Use it instead of `pumpAndSettle` after
/// `pumpWidget` when the app starts signed out.
Future<void> pumpUntilWelcome(WidgetTester tester) async {
  await pumpUntilFound(tester, find.byKey(WelcomeScreen.hintKey));
  await pumpUntilFound(
    tester,
    find.byKey(WelcomeScreen.signInButtonKey).hitTestable(),
  );
}

/// Wakes the Buddy and taps through his intro lines until „Los geht's"
/// ([WelcomeScreen.registrationButtonKey]) shows.
Future<void> finishWelcomeStory(WidgetTester tester) async {
  final area = find.byKey(WelcomeScreen.buddyAreaKey);
  final button = find.byKey(WelcomeScreen.registrationButtonKey);
  await tester.tap(area);
  // Taps while he wakes up are ignored; after that each tap shows the next
  // line, and the last line brings the button.
  for (var i = 0; i < 20 && button.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (button.evaluate().isEmpty) await tester.tap(area);
  }
  await pumpUntilFound(tester, button);
  // Let the button finish sliding in before it is tapped.
  await tester.pump(const Duration(milliseconds: 500));
}
