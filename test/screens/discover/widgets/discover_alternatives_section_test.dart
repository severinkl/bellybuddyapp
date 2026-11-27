import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/models/ranked_replacement.dart';
import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/models/replacement_ingredient.dart';
import 'package:belly_buddy/screens/discover/widgets/discover_alternatives_section.dart';

import '../../../helpers/purchases_fakes.dart';

void main() {
  testWidgets('„Stattdessen: …" shows on two lines', (tester) async {
    final group = IngredientSuggestionGroup(
      ingredientId: 'ing-onion',
      ingredientName: 'Zwiebel',
      mealCount: 1,
      isNew: false,
      suggestionIds: ['s1'],
      replacements: RankedReplacement.inOrder(const [
        ReplacementIngredient(id: 'r1', name: 'Schnittlauch'),
        ReplacementIngredient(id: 'r2', name: 'Lauchgrün'),
        ReplacementIngredient(id: 'r3', name: 'Asafoetida'),
        ReplacementIngredient(id: 'r4', name: 'Knoblauchöl'),
      ]),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: plusOpenOverrides,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: DiscoverAlternativesSection(
                groups: AsyncValue.data([group]),
                newCount: 0,
                onOpen: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final line = find.textContaining('Stattdessen:');
    expect(tester.widget<Text>(line).maxLines, 2);
    // The four names don't fit one line at 320 px: the text takes two.
    expect(
      tester.getSize(line).height,
      greaterThan(AppTheme.fontSizeCaptionLG * 1.5),
    );
  });
}
