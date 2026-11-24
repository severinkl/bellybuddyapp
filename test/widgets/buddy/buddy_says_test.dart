import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:belly_buddy/widgets/buddy/buddy_says.dart';
import 'package:belly_buddy/widgets/buddy/buddy_side_header.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget says) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: says)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('on a stage: the line above him, as high as asked', (
    tester,
  ) async {
    await pump(
      tester,
      const BuddySays(mood: BuddyMood.zen, line: 'Einen Moment', height: 200),
    );

    final stage = find.byType(BuddyStage);
    expect(tester.getSize(stage).height, 200);
    expect(tester.widget<BuddyStage>(stage).controller.mood, BuddyMood.zen);
    expect(find.text('Einen Moment'), findsOneWidget);
    expect(find.byType(BuddySideHeader), findsNothing);
  });

  testWidgets('beside: the whole line, in the font size asked', (tester) async {
    await pump(
      tester,
      const BuddySays.beside(
        mood: BuddyMood.empathetic,
        line: 'Das hat nicht geklappt.',
        height: 88,
        fontSize: AppTheme.fontSizeBodyLG,
      ),
    );

    final header = tester.widget<BuddySideHeader>(find.byType(BuddySideHeader));
    expect(header.grow, isTrue);
    expect(header.buddySize.height, 88);
    expect(header.fontSize, AppTheme.fontSizeBodyLG);
    expect(header.controller.mood, BuddyMood.empathetic);
    expect(find.text('Das hat nicht geklappt.'), findsOneWidget);
    expect(find.byType(BuddyStage), findsNothing);
  });

  testWidgets('a new line or mood is said by the same Buddy', (tester) async {
    await pump(
      tester,
      const BuddySays(mood: BuddyMood.happy, line: 'Eins', height: 200),
    );
    final controller = tester
        .widget<BuddyStage>(find.byType(BuddyStage))
        .controller;

    await pump(
      tester,
      const BuddySays(mood: BuddyMood.zen, line: 'Zwei', height: 200),
    );

    expect(
      tester.widget<BuddyStage>(find.byType(BuddyStage)).controller,
      same(controller),
    );
    expect(controller.mood, BuddyMood.zen);
    expect(find.text('Zwei'), findsOneWidget);
    expect(find.text('Eins'), findsNothing);
  });
}
