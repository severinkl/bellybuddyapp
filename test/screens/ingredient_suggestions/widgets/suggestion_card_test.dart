import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/screens/ingredient_suggestions/widgets/suggestion_card.dart';
import 'package:belly_buddy/screens/ingredient_suggestions/widgets/suggestion_detail_modal.dart';

void main() {
  const tofu = IngredientSuggestionGroup(
    ingredientId: 'ing-tofu',
    ingredientName: 'Tofu',
    mealCount: 1,
    isNew: true,
    suggestionIds: ['s1'],
  );

  testWidgets('an ingredient without an image gets a neutral placeholder, '
      'not a lettuce', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuggestionCard(group: tofu, onTap: () {}, onDismiss: () {}),
        ),
      ),
    );

    expect(find.text('\u{1F96C}'), findsNothing);
    expect(find.byIcon(Icons.restaurant), findsOneWidget);
  });

  testWidgets('the detail sheet too', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SuggestionDetailModal(group: tofu)),
      ),
    );

    expect(find.text('\u{1F96C}'), findsNothing);
    expect(find.byIcon(Icons.restaurant), findsOneWidget);
  });
}
