import 'package:flutter/material.dart';
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
  });
}
