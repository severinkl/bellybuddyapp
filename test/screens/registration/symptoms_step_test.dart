import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/symptom_options.dart';
import 'package:belly_buddy/screens/registration/steps/steps.dart';

import '../../helpers/riverpod_helpers.dart';

void main() {
  testWidgets('symptoms are a multi-select: checkboxes, not radio circles', (
    tester,
  ) async {
    await tester.pumpWithProviders(
      Scaffold(
        body: SingleChildScrollView(
          child: SymptomsStep(
            selected: const ['Verstopfung'],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.circle_outlined), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    expect(
      find.byIcon(Icons.check_box_outline_blank),
      findsNWidgets(kRegistrationSymptomOptions.length - 1),
    );
  });

  testWidgets('a pick is stored as the canonical value Mein Profil uses', (
    tester,
  ) async {
    List<String>? picked;
    await tester.pumpWithProviders(
      Scaffold(
        body: SingleChildScrollView(
          child: SymptomsStep(selected: const [], onChanged: (v) => picked = v),
        ),
      ),
    );

    await tester.tap(find.text('Verstopfung'));
    expect(picked, ['Verstopfung']);
    expect(find.text('Nervige Verstopfung'), findsNothing);
  });
}
