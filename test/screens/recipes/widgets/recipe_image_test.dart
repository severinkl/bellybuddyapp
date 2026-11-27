import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_image.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/reduce_motion.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SizedBox(width: 120, height: 120, child: child)),
    ),
  );

  Recipe withImage(String url) => Recipe(
    id: 'r',
    title: 'Mit Bild',
    imageUrl: url,
    mealTypes: const [MealType.lunch],
  );

  Color tintOf(WidgetTester tester) => tester
      .widget<ColoredBox>(find.byKey(RecipePlaceholder.placeholderKey))
      .color;

  group('RecipePlaceholder', () {
    const expected = {
      MealType.breakfast: AppTheme.recipeTintBreakfast,
      MealType.lunch: AppTheme.recipeTintLunch,
      MealType.dinner: AppTheme.recipeTintDinner,
      MealType.snack: AppTheme.recipeTintSnack,
    };
    for (final entry in expected.entries) {
      testWidgets('${entry.key.label} paints its tint', (tester) async {
        await pump(tester, RecipePlaceholder(mealType: entry.key));
        expect(tintOf(tester), entry.value);
      });
    }

    testWidgets('no meal type paints the other tint', (tester) async {
      await pump(tester, const RecipePlaceholder());
      expect(tintOf(tester), AppTheme.recipeTintOther);
    });

    testWidgets('has an icon and no semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const RecipePlaceholder(mealType: MealType.lunch));
      expect(find.byType(Icon), findsOneWidget);
      expect(tester.getSemantics(find.byType(Icon)).label, isEmpty);
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
      handle.dispose();
    });
  });

  group('RecipeImage', () {
    testWidgets('null url shows the placeholder by meal type', (tester) async {
      await pump(
        tester,
        RecipeImage(recipe: testRecipe(mealTypes: const [MealType.dinner])),
      );
      expect(tintOf(tester), AppTheme.recipeTintDinner);
      expect(find.byType(CachedNetworkImage), findsNothing);
    });

    testWidgets('an https url is a CachedNetworkImage', (tester) async {
      await pump(
        tester,
        RecipeImage(recipe: withImage('https://x.test/a.jpg')),
      );
      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.imageUrl, 'https://x.test/a.jpg');
      expect(image.fit, BoxFit.cover);
      final context = tester.element(find.byType(CachedNetworkImage));
      expect(
        image.placeholder!(context, image.imageUrl),
        isA<Shimmer>().having((s) => s.enabled, 'enabled', isTrue),
      );
      expect(
        image.errorWidget!(context, image.imageUrl, Object()),
        isA<RecipePlaceholder>(),
      );
    });

    testWidgets('decodes at its laid-out size, not the photo\'s', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 160,
                height: 90,
                child: RecipeImage(recipe: withImage('https://x.test/a.jpg')),
              ),
            ),
          ),
        ),
      );
      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      // The longer side, so a landscape photo still covers the box sharply.
      expect(image.memCacheHeight, 320);
      expect(image.memCacheWidth, isNull);
    });

    testWidgets('another scheme is the placeholder', (tester) async {
      await pump(tester, RecipeImage(recipe: withImage('ftp://x')));
      expect(find.byKey(RecipePlaceholder.placeholderKey), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
    });

    testWidgets('with reduced motion the shimmer is disabled', (tester) async {
      reduceMotion(tester);
      await pump(
        tester,
        RecipeImage(recipe: withImage('https://x.test/a.jpg')),
      );
      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      final context = tester.element(find.byType(CachedNetworkImage));
      final shimmer = image.placeholder!(context, image.imageUrl) as Shimmer;
      expect(shimmer.enabled, isFalse);
    });
  });
}
