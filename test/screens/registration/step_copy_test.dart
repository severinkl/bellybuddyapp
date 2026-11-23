import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/screens/registration/steps/email_capture_step.dart';
import 'package:belly_buddy/screens/registration/steps/steps.dart';
import 'package:belly_buddy/screens/registration/widgets/step_field_label.dart';

import '../../helpers/riverpod_helpers.dart';

void main() {
  group('StepFieldLabel', () {
    testWidgets('writes ß as SS in capitals', (tester) async {
      await tester.pumpWithProviders(
        const Scaffold(body: StepFieldLabel('Größe & Gewicht')),
      );

      expect(find.text('GRÖSSE & GEWICHT'), findsOneWidget);
      expect(find.textContaining('ß'), findsNothing);
    });
  });

  group('the wizard steps speak with one voice', () {
    // The Buddy says „ich"; the steps' subtitles are his or neutral, never a
    // „wir"/„uns" of the app.
    final weVoice = RegExp(r'\b([Ww]ir|[Uu]ns|[Uu]nser\w*)\b');

    final steps = <String, Widget>{
      'birth year': BirthYearStep(value: 1990, onChanged: (_) {}),
      'gender': GenderStep(value: null, onChanged: (_) {}),
      'height and weight': HeightWeightStep(
        height: 170,
        weight: 70,
        onHeightChanged: (_) {},
        onWeightChanged: (_) {},
      ),
      'diet': DietStep(value: null, onChanged: (_) {}),
      'symptoms': SymptomsStep(selected: const [], onChanged: (_) {}),
      'intolerances': IntolerancesStep(
        selected: const [],
        onChanged: (_) {},
        triggers: const {},
        onTriggersChanged: (_, _) {},
      ),
      'email capture': EmailCaptureStep(
        value: null,
        onChanged: (_) {},
        onSubmit: () {},
        onSkip: () {},
      ),
    };

    for (final MapEntry(key: name, value: step) in steps.entries) {
      testWidgets(name, (tester) async {
        await tester.pumpWithProviders(Scaffold(body: step));

        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
            .where(weVoice.hasMatch)
            .toList();
        expect(texts, isEmpty);
      });
    }
  });
}
