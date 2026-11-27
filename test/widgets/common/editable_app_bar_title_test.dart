import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/widgets/common/editable_app_bar_title.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(appBar: AppBar(title: child)),
);

void main() {
  group('EditableAppBarTitle', () {
    testWidgets('renders title text + pencil icon in display mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EditableAppBarTitle(
            initialTitle: 'Mahlzeit X',
            placeholder: 'Mahlzeit benennen',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Mahlzeit X'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('shows placeholder when title is empty', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EditableAppBarTitle(
            initialTitle: '',
            placeholder: 'Mahlzeit benennen',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Mahlzeit benennen'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('tapping the title enters edit mode with a TextField', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EditableAppBarTitle(
            initialTitle: 'Mahlzeit X',
            placeholder: 'Mahlzeit benennen',
            onChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.text('Mahlzeit X'));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets(
      'onChanged fires with trimmed value on submit; widget returns to display mode',
      (tester) async {
        String? captured;
        await tester.pumpWidget(
          _wrap(
            EditableAppBarTitle(
              initialTitle: '',
              placeholder: 'Mahlzeit benennen',
              onChanged: (v) => captured = v,
            ),
          ),
        );

        await tester.tap(find.text('Mahlzeit benennen'));
        await tester.pump();
        await tester.enterText(find.byType(TextField), '  Pizza Funghi  ');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(captured, equals('Pizza Funghi'));
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Pizza Funghi'), findsOneWidget);
      },
    );

    testWidgets('in display mode the title is a button „Titel bearbeiten" '
        'with the title as its value; tapping it edits', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          EditableAppBarTitle(
            initialTitle: 'Mahlzeit X',
            placeholder: 'Mahlzeit benennen',
            onChanged: (_) {},
          ),
        ),
      );

      final title = find.semantics.byLabel('Titel bearbeiten');
      expect(title, findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Titel bearbeiten')),
        isSemantics(isButton: true, value: 'Mahlzeit X', hasTapAction: true),
      );
      tester.semantics.tap(title);
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      handle.dispose();
    });

    testWidgets('in edit mode the field keeps its name „Titel" after typing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          EditableAppBarTitle(
            initialTitle: '',
            placeholder: 'Rezept benennen',
            autofocusOnMount: true,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Curry');
      await tester.pumpAndSettle();

      final node = tester.getSemantics(find.byType(TextField));
      expect(node.getSemanticsData().label, contains('Titel'));
      expect(node, isSemantics(isTextField: true, value: 'Curry'));
      handle.dispose();
    });

    testWidgets('autofocusOnMount: true starts in edit mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EditableAppBarTitle(
            initialTitle: '',
            placeholder: 'Rezept benennen',
            autofocusOnMount: true,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets(
      'onTextChanged fires per keystroke (raw value, not trimmed) and '
      'onChanged fires once on submit (trimmed value)',
      (tester) async {
        final textChangedValues = <String>[];
        String? committed;
        await tester.pumpWidget(
          _wrap(
            EditableAppBarTitle(
              initialTitle: '',
              placeholder: 'Mahlzeit benennen',
              onChanged: (v) => committed = v,
              onTextChanged: textChangedValues.add,
            ),
          ),
        );

        await tester.tap(find.text('Mahlzeit benennen'));
        await tester.pump();
        await tester.enterText(find.byType(TextField), '  Pizza  ');
        expect(textChangedValues.last, equals('  Pizza  '));

        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(committed, equals('Pizza'));
      },
    );
  });
}
