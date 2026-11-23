import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:belly_buddy/widgets/buddy/buddy_ask_sheet.dart';

void main() {
  /// A page whose „open" button opens a [BuddyAskSheet] in [mood] whose
  /// „Ja" pops 1; each result goes to [results].
  Future<void> pumpOpener(
    WidgetTester tester,
    List<int?> results, {
    BuddyMood mood = BuddyMood.happy,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.theme,
      home: Scaffold(
        body: Builder(
          builder: (c) => TextButton(
            onPressed: () async => results.add(
              await showBuddySheet<int>(
                c,
                builder: (context) => BuddyAskSheet(
                  line: 'Magst du?',
                  mood: mood,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, 1),
                    child: const Text('Ja'),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('the Buddy says the line in the mood, the answers below him', (
    tester,
  ) async {
    await pumpOpener(tester, [], mood: BuddyMood.inLove);
    await open(tester);

    expect(find.text('Magst du?'), findsOneWidget);
    final stage = find.byType(BuddyStage);
    expect(tester.getSize(stage).height, AppConstants.streakSheetBuddyHeight);
    expect(tester.widget<BuddyStage>(stage).controller.mood, BuddyMood.inLove);
    expect(
      tester.getTopLeft(find.text('Ja')).dy,
      greaterThan(tester.getBottomLeft(stage).dy),
    );
  });

  testWidgets('returns what it pops with; null when dismissed', (tester) async {
    final results = <int?>[];
    await pumpOpener(tester, results);

    await open(tester);
    await tester.tap(find.text('Ja'));
    await tester.pumpAndSettle();
    await open(tester);
    await tester.tapAt(const Offset(10, 10)); // modal barrier
    await tester.pumpAndSettle();

    expect(results, [1, null]);
  });
}
