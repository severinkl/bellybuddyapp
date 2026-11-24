import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/screens/recipes/widgets/fit_badge_view.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_collection_card.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_page_parts.dart';
import 'package:belly_buddy/services/recipes/recipe_copy.dart';
import 'package:belly_buddy/services/recipes/recipe_fit.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  group('RecipePageHead', () {
    const picture = Key('picture');

    testWidgets('picture, title as the heading, meta and badge', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        const RecipePageHead(
          image: ColoredBox(key: picture, color: Colors.black),
          title: 'Reis mit Honig',
          meta: '35 Min · 2 Portionen',
          badge: KritischBadge(1),
        ),
      );

      expect(find.byKey(picture), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Reis mit Honig')),
        matchesSemantics(label: 'Reis mit Honig', isHeader: true),
      );
      expect(find.text('35 Min · 2 Portionen'), findsOneWidget);
      expect(find.byType(FitBadgeView), findsOneWidget);
      expect(find.byType(RecipeTagPill), findsNothing);
      // Title, meta and badge below the picture, in that order.
      final pictureBottom = tester.getBottomLeft(find.byKey(picture)).dy;
      final title = tester.getTopLeft(find.text('Reis mit Honig')).dy;
      final meta = tester.getTopLeft(find.text('35 Min · 2 Portionen')).dy;
      final badge = tester.getTopLeft(find.byType(FitBadgeView)).dy;
      expect(title, greaterThan(pictureBottom));
      expect(meta, greaterThan(title));
      expect(badge, greaterThan(meta));
      semantics.dispose();
    });

    testWidgets('an adapted tag sits on the picture, „Für dich angepasst"', (
      tester,
    ) async {
      await pump(
        tester,
        const RecipePageHead(
          image: ColoredBox(key: picture, color: Colors.black),
          tag: RecipeCardTag.adapted,
          title: 'Risotto',
        ),
      );

      final pill = find.byType(RecipeTagPill);
      expect(
        find.descendant(
          of: pill,
          matching: find.text(RecipeCopy.adaptedForYou),
        ),
        findsOneWidget,
      );
      final pictureRect = tester.getRect(find.byKey(picture));
      expect(pictureRect.contains(tester.getCenter(pill)), isTrue);
      // No meta, no badge: nothing below the title.
      expect(find.byType(RecipeMetaLine), findsNothing);
      expect(find.byType(FitBadgeView), findsNothing);
    });
  });

  group('RecipeSectionCard', () {
    testWidgets('servings as „für …" at the heading', (tester) async {
      await pump(
        tester,
        const RecipeSectionCard(
          title: 'Zutaten',
          servings: '2 Portionen',
          children: [Text('Reis')],
        ),
      );

      expect(find.text('für 2 Portionen'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('für 2 Portionen')).style,
        AppTheme.captionMutedStyle,
      );
    });

    testWidgets('without servings: no caption', (tester) async {
      await pump(
        tester,
        const RecipeSectionCard(title: 'Zutaten', children: [Text('Reis')]),
      );

      expect(find.textContaining('für '), findsNothing);
    });
  });
}
