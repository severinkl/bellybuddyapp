import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/trackers/meal/widgets/meal_image_section.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('MealImageSection empty state', () {
    testWidgets('omits the Rezept button when onPickRecipe is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MealImageSection(
            imageBytes: null,
            isAnalyzing: false,
            onImagePicked: (_, _) async {},
            onClearImage: () {},
          ),
        ),
      );

      expect(find.text('Kamera'), findsOneWidget);
      expect(find.text('Galerie'), findsOneWidget);
      expect(find.text('Rezept'), findsNothing);
    });

    testWidgets(
      'renders the Rezept button when onPickRecipe is provided and fires it on tap',
      (tester) async {
        var tapped = 0;
        await tester.pumpWidget(
          _wrap(
            MealImageSection(
              imageBytes: null,
              isAnalyzing: false,
              onImagePicked: (_, _) async {},
              onClearImage: () {},
              onPickRecipe: () => tapped++,
            ),
          ),
        );

        expect(find.text('Rezept'), findsOneWidget);
        await tester.tap(find.text('Rezept'));
        await tester.pump();
        expect(tapped, 1);
      },
    );
  });
}
