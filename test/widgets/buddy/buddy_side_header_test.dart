import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:belly_buddy/widgets/buddy/buddy_side_header.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final long = List.filled(
    10,
    'Ich hab Honig gegen Ahornsirup getauscht.',
  ).join(' ');
  const buddy = Size(60, 85);

  Future<void> pump(WidgetTester tester, {bool grow = false}) async {
    final controller = BuddyController()..say(long, duration: null);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuddySideHeader(
              controller: controller,
              buddySize: buddy,
              grow: grow,
              fontSize: AppTheme.fontSizeBody,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  RenderParagraph paragraph(WidgetTester tester) =>
      tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(BuddySpeechBubble),
          matching: find.byType(RichText),
        ),
      );

  testWidgets('by default the bubble fits into the Buddy\'s height', (
    tester,
  ) async {
    await pump(tester);

    expect(tester.getSize(find.byType(BuddySideHeader)).height, buddy.height);
    expect(paragraph(tester).didExceedMaxLines, isTrue);
  });

  testWidgets('grow: the header grows with the whole text', (tester) async {
    await pump(tester, grow: true);

    expect(paragraph(tester).didExceedMaxLines, isFalse);
    final header = tester.getRect(find.byType(BuddySideHeader));
    final bubble = tester.getRect(find.byType(BuddySpeechBubble));
    expect(header.height, greaterThan(buddy.height));
    expect(bubble.bottom, lessThanOrEqualTo(header.bottom));
    expect(paragraph(tester).text.style?.fontSize, AppTheme.fontSizeBody);
  });

  testWidgets('grow: a short text keeps the Buddy\'s height', (tester) async {
    final controller = BuddyController()..say('Hallo!', duration: null);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuddySideHeader(
              controller: controller,
              buddySize: buddy,
              grow: true,
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(BuddySideHeader)).height, buddy.height);
  });
}
