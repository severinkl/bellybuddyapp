import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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
            selected: const ['Nervige Verstopfung'],
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
      findsNWidgets(kRegistrationSymptoms.length - 1),
    );
  });
}
