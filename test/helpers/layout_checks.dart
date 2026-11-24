import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/widgets/buddy/animated_buddy.dart';
import 'package:belly_buddy/widgets/buddy/buddy_speech_bubble.dart';
import 'package:belly_buddy/widgets/buddy/need_meter.dart';

/// Runs [body] with Flutter's errors collected instead of failing the test,
/// and returns their messages (see [verticalOverflows]).
Future<List<String>> collectFlutterErrors(Future<void> Function() body) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

/// The overflows at the bottom or top among [errors]: content taller than
/// its box. (The test font's square glyphs are much wider than the app's,
/// so some rows overflow sideways in tests only.)
List<String> verticalOverflows(List<String> errors) => [
  for (final e in errors)
    if (e.contains('overflowed') &&
        (e.contains('on the bottom') || e.contains('on the top')))
      e,
];

/// How much [element]'s render box is scaled as drawn (1 when nothing
/// above it scales it).
double drawnScale(Element element) {
  final box = element.renderObject! as RenderBox;
  final drawn = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
  return drawn.height / box.size.height;
}

/// The least the Buddy is drawn tall on a success page, with his body.
const minBuddyHeight = 24.0;

/// A tracker's success page fits its screen: no vertical overflow among
/// [errors], the Buddy drawn with a body, and every text of it ([page])
/// drawn at the user's text scale, never smaller. Not checked: a meter's
/// emoji (an icon that grows and shrinks with its circle) and the Buddy's
/// speech bubble, which his stage fits into its slot (the test font's
/// glyphs make it far wider than in the app).
void expectSuccessPageFits(
  WidgetTester tester,
  List<String> errors, {
  required Finder page,
}) {
  expect(verticalOverflows(errors), isEmpty);
  expect(
    tester.getRect(find.byType(AnimatedBuddy)).height,
    greaterThanOrEqualTo(minBuddyHeight),
  );
  final unchecked = {
    for (final type in [NeedMeter, BuddySpeechBubble])
      ...find
          .descendant(of: find.byType(type), matching: find.byType(RichText))
          .evaluate(),
  };
  final texts = find.descendant(of: page, matching: find.byType(RichText));
  expect(texts, findsWidgets);
  for (final text in texts.evaluate().where((t) => !unchecked.contains(t))) {
    expect(
      drawnScale(text),
      moreOrLessEquals(1, epsilon: 0.001),
      reason: (text.widget as RichText).text.toPlainText(),
    );
  }
}
