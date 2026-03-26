import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/widgets/common/bb_password_field.dart';

import '../helpers/riverpod_helpers.dart';

void main() {
  group('BbPasswordField', () {
    testWidgets('text is obscured by default', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWithProviders(
        Scaffold(body: BbPasswordField(controller: controller)),
      );
      // The EditableText inside renders with obscureText
      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(editableText.obscureText, isTrue);
    });

    testWidgets('toggle button reveals text', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWithProviders(
        Scaffold(body: BbPasswordField(controller: controller)),
      );

      // Initially obscured — visibility_off icon is shown
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      // Tap toggle to reveal
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(editableText.obscureText, isFalse);
    });

    testWidgets('onChanged fires with entered text', (tester) async {
      final controller = TextEditingController();
      String? changed;
      await tester.pumpWithProviders(
        Scaffold(
          body: BbPasswordField(
            controller: controller,
            onChanged: (value) => changed = value,
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'geheim123');
      await tester.pump();
      expect(changed, 'geheim123');
    });

    testWidgets('renders default label text', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWithProviders(
        Scaffold(body: BbPasswordField(controller: controller)),
      );
      expect(find.text('Passwort'), findsOneWidget);
    });
  });
}
