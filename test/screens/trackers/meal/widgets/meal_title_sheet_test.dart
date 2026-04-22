import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/trackers/meal/widgets/meal_title_sheet.dart';

/// Pumps a minimal MaterialApp + button, taps the button to open the sheet,
/// and returns the sheet's own future. Callers must **await this helper**
/// so the pump-and-tap dance completes before they interact with the sheet,
/// and then `await` the returned future at the end of the test to read the
/// sheet's result.
///
/// Using `pumpAndSettle` inside would hang on the autofocused TextField's
/// cursor-blink animation; fixed-duration pumps handle the slide-in instead.
Future<Future<MealTitleSheetOutcome?>> _openSheet(WidgetTester tester) async {
  late Future<MealTitleSheetOutcome?> sheetFuture;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () {
                sheetFuture = showMealTitleSheet(ctx);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return sheetFuture;
}

/// Lets the sheet's dismiss / Navigator.pop transition finish without
/// triggering `pumpAndSettle`'s cursor-blink hang.
Future<void> _waitForNavPop(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('showMealTitleSheet', () {
    testWidgets('submit returns MealTitleEntered with trimmed title', (
      tester,
    ) async {
      final future = await _openSheet(tester);

      await tester.enterText(
        find.byKey(mealTitleSheetFieldKey),
        '  Pasta mit Tomaten  ',
      );
      await tester.pump();

      await tester.tap(find.byKey(mealTitleSheetSubmitKey));
      await _waitForNavPop(tester);

      final result = await future;
      expect(result, isA<MealTitleEntered>());
      expect((result as MealTitleEntered).title, 'Pasta mit Tomaten');
    });

    testWidgets('keyboard Done (onSubmitted) also returns MealTitleEntered', (
      tester,
    ) async {
      final future = await _openSheet(tester);

      await tester.enterText(
        find.byKey(mealTitleSheetFieldKey),
        'Haferflocken mit Beeren',
      );
      await tester.pump();

      // Simulate the soft-keyboard "Done" action — hits the TextField's
      // onSubmitted, which should dispatch the same path as tapping the
      // primary button.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _waitForNavPop(tester);

      final result = await future;
      expect(result, isA<MealTitleEntered>());
      expect((result as MealTitleEntered).title, 'Haferflocken mit Beeren');
    });

    testWidgets('primary is disabled until the field has non-whitespace text', (
      tester,
    ) async {
      await _openSheet(tester);

      final initial = tester.widget<FilledButton>(
        find.byKey(mealTitleSheetSubmitKey),
      );
      expect(initial.onPressed, isNull);

      await tester.enterText(find.byKey(mealTitleSheetFieldKey), '   ');
      await tester.pump();
      final stillDisabled = tester.widget<FilledButton>(
        find.byKey(mealTitleSheetSubmitKey),
      );
      expect(stillDisabled.onPressed, isNull);

      await tester.enterText(
        find.byKey(mealTitleSheetFieldKey),
        'Haferflocken',
      );
      await tester.pump();
      final enabled = tester.widget<FilledButton>(
        find.byKey(mealTitleSheetSubmitKey),
      );
      expect(enabled.onPressed, isNotNull);
    });

    testWidgets('"Ohne Namen speichern" returns MealTitleSkipped', (
      tester,
    ) async {
      final future = await _openSheet(tester);

      await tester.tap(find.byKey(mealTitleSheetSkipKey));
      await _waitForNavPop(tester);

      final result = await future;
      expect(result, isA<MealTitleSkipped>());
    });

    testWidgets('tapping the barrier dismisses the sheet → future is null', (
      tester,
    ) async {
      final future = await _openSheet(tester);

      // The modal barrier sits above the sheet and covers the rest of the
      // screen. Tapping near the top-left hits the barrier.
      await tester.tapAt(const Offset(20, 20));
      await _waitForNavPop(tester);

      final result = await future;
      expect(result, isNull);
    });
  });
}
