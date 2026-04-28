import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/screens/recipes/widgets/recipes_tab_toggle.dart';

void main() {
  testWidgets('renders both segment labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipesTabToggle(
            value: 0,
            segments: const ['Meine Rezepte', 'Inspiration'],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Meine Rezepte'), findsOneWidget);
    expect(find.text('Inspiration'), findsOneWidget);
  });

  testWidgets('tapping the inactive segment fires onChanged with its index', (
    tester,
  ) async {
    int? lastSelected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipesTabToggle(
            value: 0,
            segments: const ['Meine Rezepte', 'Inspiration'],
            onChanged: (i) => lastSelected = i,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Inspiration'));
    expect(lastSelected, 1);
  });

  testWidgets('renders no checkmark icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipesTabToggle(
            value: 0,
            segments: const ['Meine Rezepte', 'Inspiration'],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check), findsNothing);
  });
}
