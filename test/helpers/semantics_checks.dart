import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// An empty search field ([field], default the only [EditableText]) is
/// read with its [name] once and its placeholder [example] („z. B. …"),
/// not with the name twice (label and placeholder alike).
void expectSearchFieldReadOnce(
  WidgetTester tester, {
  required String name,
  required String example,
  Finder? field,
}) {
  expect(example, startsWith('z. B. '));
  expect(find.text(example), findsOneWidget, reason: 'the placeholder shows');
  final data = tester
      .getSemantics(field ?? find.byType(EditableText))
      .getSemanticsData();
  final read = '${data.label} ${data.hint}';
  expect(
    RegExp(RegExp.escape(name)).allMatches(read),
    hasLength(1),
    reason: 'read: „$read"',
  );
  expect(read, contains(example));
}
