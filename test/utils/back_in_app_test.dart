import 'package:flutter/gestures.dart' show GestureBinding;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/utils/back_in_app.dart';

import '../helpers/app_lifecycle.dart';

void main() {
  /// Whether [backInApp]'s future has completed.
  Future<bool Function()> started(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    var back = false;
    backInApp().then((_) => back = true).ignore();
    await tester.pump();
    return () => back;
  }

  testWidgets('waits while nothing happens', (tester) async {
    final back = await started(tester);

    await tester.pump(const Duration(minutes: 5));

    expect(back(), isFalse);
  });

  testWidgets('a touch on the app: back (iOS, the in-app browser closed)', (
    tester,
  ) async {
    final back = await started(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();

    expect(back(), isTrue);
  });

  testWidgets('resumed after the app was left: back (Android Custom Tabs)', (
    tester,
  ) async {
    final back = await started(tester);

    returnFromBackground();
    await tester.pump();

    expect(back(), isTrue);
  });

  testWidgets('resumed after a blip to inactive: back', (tester) async {
    final back = await started(tester);

    inactiveBlip();
    await tester.pump();

    expect(back(), isTrue);
  });

  testWidgets('left before it started (the launch resolved late): the '
      'resume brings it back', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final binding = tester.binding;
    binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    var back = false;
    backInApp().then((_) => back = true).ignore();
    await tester.pump();
    expect(back, isFalse);

    binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(back, isTrue);
  });

  testWidgets('both: completes once, and stops listening', (tester) async {
    final router = GestureBinding.instance.pointerRouter;
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final routes = router.debugGlobalRouteCount;
    final back = await started(tester);
    expect(router.debugGlobalRouteCount, routes + 1);

    await tester.tapAt(const Offset(10, 10));
    inactiveBlip();
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();

    expect(back(), isTrue);
    expect(router.debugGlobalRouteCount, routes);
  });
}
