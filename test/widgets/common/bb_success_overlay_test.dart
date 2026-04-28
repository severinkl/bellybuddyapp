import 'package:belly_buddy/widgets/common/bb_success_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Pumps past all staggered animation timers in [BbSuccessOverlay.initState]
/// (100 ms mascot delay + 250 ms text delay + animation durations ≤ 600 ms).
/// Draining to 700 ms leaves no pending timers while still within test bounds.
Future<void> _pumpOverlay(WidgetTester tester, Widget overlay) async {
  await tester.pumpWidget(_wrap(overlay));
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  group('BbSuccessOverlay actions', () {
    testWidgets('renders multiple actions separated by gaps', (tester) async {
      await _pumpOverlay(
        tester,
        BbSuccessOverlay(
          message: 'Gespeichert!',
          onDismissed: () {},
          // mascotAsset keeps the overlay alive (no auto-dismiss timer).
          mascotAsset: 'assets/images/mascot/mascot-cool.png',
          actions: const [Text('Aktion 1'), Text('Aktion 2')],
        ),
      );

      expect(find.text('Aktion 1'), findsOneWidget);
      expect(find.text('Aktion 2'), findsOneWidget);
    });

    testWidgets('renders without actions gracefully (no exception)', (
      tester,
    ) async {
      // Provide a mascot so the overlay does not schedule an auto-dismiss timer.
      await _pumpOverlay(
        tester,
        BbSuccessOverlay(
          message: 'Gespeichert!',
          onDismissed: () {},
          mascotAsset: 'assets/images/mascot/mascot-happy.png',
          // actions omitted — must not throw
        ),
      );

      expect(find.text('Gespeichert!'), findsOneWidget);
    });

    testWidgets('renders with empty actions list gracefully', (tester) async {
      await _pumpOverlay(
        tester,
        BbSuccessOverlay(
          message: 'Gespeichert!',
          onDismissed: () {},
          mascotAsset: 'assets/images/mascot/mascot-happy.png',
          actions: const [],
        ),
      );

      expect(find.text('Gespeichert!'), findsOneWidget);
    });

    testWidgets('renders single action', (tester) async {
      await _pumpOverlay(
        tester,
        BbSuccessOverlay(
          message: 'Gespeichert!',
          onDismissed: () {},
          mascotAsset: 'assets/images/mascot/mascot-cool.png',
          actions: const [Text('Nur eine Aktion')],
        ),
      );

      expect(find.text('Nur eine Aktion'), findsOneWidget);
    });

    testWidgets('renders bottomCallout below actions', (tester) async {
      await _pumpOverlay(
        tester,
        BbSuccessOverlay(
          message: 'Gespeichert',
          onDismissed: () {},
          actions: const [Text('ACTION_ONE')],
          bottomCallout: const Text('CALLOUT_TEXT'),
        ),
      );

      expect(find.text('ACTION_ONE'), findsOneWidget);
      expect(find.text('CALLOUT_TEXT'), findsOneWidget);
    });

    testWidgets('renders cleanly without bottomCallout', (tester) async {
      await _pumpOverlay(
        tester,
        BbSuccessOverlay(
          message: 'Gespeichert',
          onDismissed: () {},
          actions: const [Text('ACTION_ONE')],
        ),
      );

      expect(find.text('ACTION_ONE'), findsOneWidget);
    });
  });
}
