import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';

import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/models/replacement_ingredient.dart';
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

  testWidgets('an Alternativen card offers „Ausblenden", which dismisses it '
      'like a swipe', (tester) async {
    final handle = tester.ensureSemantics();
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuggestionCard(
            group: tofu,
            onTap: () {},
            onDismiss: () => dismissed++,
          ),
        ),
      ),
    );

    const action = CustomSemanticsAction(label: 'Ausblenden');
    final actionId = CustomSemanticsAction.getIdentifier(action);
    final card = find.semantics.byPredicate(
      (n) =>
          n.getSemanticsData().customSemanticsActionIds?.contains(actionId) ??
          false,
    );
    expect(card, findsOneWidget);
    tester.semantics.customAction(card, action);
    expect(dismissed, 1);
    handle.dispose();
  });

  testWidgets('an Alternativen card is a button that opens it, one node that '
      'still offers „Ausblenden"', (tester) async {
    final handle = tester.ensureSemantics();
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuggestionCard(
            group: tofu,
            onTap: () => opened++,
            onDismiss: () {},
          ),
        ),
      ),
    );

    final actionId = CustomSemanticsAction.getIdentifier(
      const CustomSemanticsAction(label: 'Ausblenden'),
    );
    final card = tester.getSemantics(find.text('Tofu'));
    expect(card, isSemantics(isButton: true, hasTapAction: true));
    expect(card.getSemanticsData().customSemanticsActionIds, [actionId]);
    tester.semantics.tap(find.semantics.byFlag(SemanticsFlag.isButton));
    expect(opened, 1);
    handle.dispose();
  });

  group('with disableAnimations the Alternativen placeholders', () {
    const withImages = IngredientSuggestionGroup(
      ingredientId: 'ing-milk',
      ingredientName: 'Milch',
      ingredientImageUrl: 'https://x.test/milk.jpg',
      mealCount: 2,
      isNew: false,
      suggestionIds: ['s2'],
      replacements: [
        ReplacementIngredient(
          id: 'r1',
          name: 'Haferdrink',
          imageUrl: 'https://x.test/oat.jpg',
        ),
      ],
    );

    Future<void> expectCalm(WidgetTester tester, Widget child) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
      final images = find.byType(CachedNetworkImage);
      expect(images, findsWidgets);
      for (final element in images.evaluate()) {
        final image = element.widget as CachedNetworkImage;
        expect(
          image.placeholder!(element, image.imageUrl),
          isNot(isA<Shimmer>()),
        );
      }
    }

    testWidgets('do not shimmer on the card', (tester) async {
      await expectCalm(
        tester,
        SuggestionCard(group: withImages, onTap: () {}, onDismiss: () {}),
      );
    });

    testWidgets('do not shimmer in the detail sheet', (tester) async {
      await expectCalm(tester, const SuggestionDetailModal(group: withImages));
    });
  });
}
