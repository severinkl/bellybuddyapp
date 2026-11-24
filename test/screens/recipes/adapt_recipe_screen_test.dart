import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:belly_buddy/config/app_theme.dart';
import 'package:belly_buddy/models/adapted_recipe.dart';
import 'package:belly_buddy/models/fodmap_flags.dart';
import 'package:belly_buddy/models/meal_prefill.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/models/user_recipe.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/recipes/adapt_recipe_screen.dart';
import 'package:belly_buddy/screens/recipes/widgets/ingredient_line_view.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_collection_card.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_image.dart';
import 'package:belly_buddy/screens/recipes/widgets/recipe_steps.dart';
import 'package:belly_buddy/services/recipes/recipe_copy.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/layout_checks.dart';
import '../../helpers/riverpod_helpers.dart';
import '../../helpers/widget_tester_helpers.dart';

void main() {
  late FakeRecipeRepository repo;
  late FakeUserRecipeRepository userRecipes;
  late RecordingUrlOpener launches;
  late Map<String, Object?> pushed;

  const sourceUrl = 'https://www.reizdarmblog.de/porridge-mit-honig';
  const note = 'Ich hab Honig gegen Ahornsirup getauscht.';
  const startQuestion = 'Soll ich das Rezept für dich umbauen?';

  /// The loading line as the bubble draws it (its „…" glued to the word
  /// before).
  final loadingLine = glueClosingSymbol(RecipeCopy.adaptWorking);

  Recipe original({String? source = sourceUrl}) => testRecipe(
    title: 'Porridge mit Honig',
    cookTime: '10 Min',
    mealTypes: const [MealType.breakfast],
    ingredients: [
      testLine('Haferflocken', amount: '50 g'),
      testLine('Haferdrink', position: 1, amount: '200 ml'),
      testLine(
        'Honig',
        position: 2,
        amount: '1 EL',
        fodmaps: const FodmapFlags(fructose: true),
      ),
    ],
    instructions: const ['Haferflocken im Haferdrink aufkochen.', 'Süßen.'],
    sourceName: 'Reizdarmblog',
    sourceUrl: source,
  );

  setUp(() {
    repo = FakeRecipeRepository()..collection = [original()];
    userRecipes = FakeUserRecipeRepository();
    launches = RecordingUrlOpener();
    pushed = {};
  });

  /// Opens the adapt screen over the recipe's detail (a stub), pushed as
  /// the detail's button does: with `extra: true` when [requested].
  Future<void> pump(
    WidgetTester tester, {
    bool requested = true,
    List<String> intolerances = const ['Fruktose'],
    double textScale = 1,
  }) async {
    GoRoute stub(String path) => GoRoute(
      path: path,
      builder: (_, state) {
        pushed[state.uri.path] = state.extra;
        return Scaffold(body: Text('page:${state.uri.path}'));
      },
    );
    final router = GoRouter(
      initialLocation: RoutePaths.collectionRecipeFor('recipe-1'),
      routes: [
        stub(RoutePaths.collectionRecipe),
        GoRoute(
          path: RoutePaths.collectionRecipeAdapt,
          builder: (_, state) => AdaptRecipeScreen(
            recipeId: state.pathParameters['id']!,
            requested: state.extra == true,
            openUrl: launches.call,
          ),
        ),
        stub(RoutePaths.recipeDetail),
        stub(RoutePaths.mealTracker),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recipeRepositoryProvider.overrideWithValue(repo),
          userRecipeRepositoryProvider.overrideWithValue(userRecipes),
          profileProviderSeededWith(
            testUserProfile(intolerances: intolerances),
          ),
          currentUserIdProvider.overrideWithValue(testUserId),
        ],
        child: germanRouterApp(router, textScale: textScale),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      router.push(
        RoutePaths.collectionRecipeAdaptFor('recipe-1'),
        extra: requested ? true : null,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The answer [repo] gives: [answer], or the failure [failure].
  void answer({AdaptedRecipe? answer, AdaptFailure? failure}) {
    repo.onAdapt = (id) async {
      if (failure != null) throw AdaptRecipeException(failure);
      return answer ?? testAdaptedRecipe(recipeId: id);
    };
  }

  Finder line(String name) =>
      find.byWidgetPredicate((w) => w is IngredientLineView && w.name == name);

  Finder inLine(String name, Finder finder) =>
      find.descendant(of: line(name), matching: finder);

  Finder inBubble(Finder finder) =>
      find.descendant(of: find.byType(BuddySpeechBubble), matching: finder);

  Finder inSave(Finder finder) => find.descendant(
    of: find.byKey(AdaptRecipeScreen.saveKey),
    matching: finder,
  );

  Finder struck(String text) => find.byWidgetPredicate((w) {
    if (w is! Text) return false;
    var found = false;
    w.textSpan?.visitChildren((s) {
      if (s is TextSpan &&
          s.text == text &&
          s.style?.decoration == TextDecoration.lineThrough) {
        found = true;
      }
      return true;
    });
    return found;
  });

  /// The colour of the box behind [text].
  Color? backgroundOf(WidgetTester tester, Finder text) {
    final box = find
        .ancestor(
          of: text,
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color != null,
          ),
        )
        .first;
    return (tester.widget<DecoratedBox>(box).decoration as BoxDecoration).color;
  }

  BuddyMood moodOf(WidgetTester tester) =>
      tester.widget<AnimatedBuddy>(find.byType(AnimatedBuddy)).controller.mood;

  String appBarTitle(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(of: find.byType(AppBar), matching: find.byType(Text)),
      )
      .data!;

  testWidgets('requested: the Buddy says the loading line, then the result', (
    tester,
  ) async {
    final reply = Completer<AdaptedRecipe>();
    repo.onAdapt = (_) => reply.future;
    await pump(tester);

    expect(repo.adaptCalls, 1);
    expect(find.byType(BuddyStage), findsOneWidget);
    expect(inBubble(find.text(loadingLine)), findsOneWidget);
    expect(find.text(RecipeCopy.adaptWorkingSub), findsOneWidget);
    expect(moodOf(tester), BuddyMood.zen);
    expect(find.byKey(AdaptRecipeScreen.startKey), findsNothing);
    expect(find.byKey(AdaptRecipeScreen.saveKey), findsNothing);
    expect(appBarTitle(tester), 'Für mich anpassen');

    reply.complete(testAdaptedRecipe());
    await tester.pumpAndSettle();

    expect(find.text(loadingLine), findsNothing);
    expect(find.text('Porridge mit Ahornsirup'), findsOneWidget);
    expect(appBarTitle(tester), 'Für dich angepasst');
    expect(find.byKey(AdaptRecipeScreen.saveKey), findsOneWidget);
    expect(find.byKey(AdaptRecipeScreen.logKey), findsOneWidget);
    expect(repo.adaptCalls, 1);
  });

  testWidgets('not requested: nothing is sent until „Für mich anpassen"', (
    tester,
  ) async {
    await pump(tester, requested: false);

    expect(repo.adaptCalls, 0);
    expect(inBubble(find.text(startQuestion)), findsOneWidget);
    // Nothing is adapted yet.
    expect(appBarTitle(tester), 'Für mich anpassen');
    expect(find.byKey(AdaptRecipeScreen.startKey), findsOneWidget);
    expect(find.text('Für mich anpassen'), findsWidgets);

    await tester.tap(find.byKey(AdaptRecipeScreen.startKey));
    await tester.pumpAndSettle();

    expect(repo.adaptCalls, 1);
    expect(find.text('Porridge mit Ahornsirup'), findsOneWidget);
  });

  testWidgets('back pops to the recipe', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();

    expect(find.text('page:/collection/recipe-1'), findsOneWidget);
  });

  group('result', () {
    testWidgets('the hero with the pill, the title, meta and servings', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byKey(RecipePlaceholder.placeholderKey), findsOneWidget);
      expect(
        tester
            .widget<RecipePlaceholder>(find.byType(RecipePlaceholder))
            .mealType,
        MealType.breakfast,
      );
      expect(
        find.descendant(
          of: find.byType(RecipeTagPill),
          matching: find.text('Für dich angepasst'),
        ),
        findsOneWidget,
      );
      expect(find.text('Porridge mit Ahornsirup'), findsOneWidget);
      expect(find.text('10 Min · 2 Portionen'), findsOneWidget);
      expect(find.text('Zutaten'), findsOneWidget);
      expect(find.text('für 2 Portionen'), findsOneWidget);
    });

    testWidgets('the swap is shown', (tester) async {
      await pump(tester);

      expect(struck('Honig'), findsOneWidget);
      expect(inLine('Ahornsirup', find.textContaining('Ahornsirup')), findsOne);
      expect(inLine('Ahornsirup', find.textContaining('getauscht')), findsOne);
      expect(
        tester.widget<IngredientLineView>(line('Ahornsirup')).replaces,
        'Honig',
      );
      for (final name in ['Haferflocken', 'Haferdrink', 'Ahornsirup']) {
        expect(inLine(name, find.byIcon(Icons.check)), findsOne, reason: name);
      }
      expect(find.text('50 g'), findsOneWidget);
    });

    testWidgets('a changed step is highlighted, with the legend', (
      tester,
    ) async {
      await pump(tester);

      Color? colorOf(Key key) =>
          (tester.widget<DecoratedBox>(find.byKey(key)).decoration
                  as BoxDecoration)
              .color;
      expect(find.text('Zubereitung'), findsOneWidget);
      expect(find.text('Mit Ahornsirup süßen.'), findsOneWidget);
      expect(colorOf(RecipeSteps.stepKey(1)), AppTheme.recipeChanged);
      expect(colorOf(RecipeSteps.stepKey(0)), isNull);
      expect(find.text('geändert'), findsOneWidget);
    });

    testWidgets('no changed step: no legend', (tester) async {
      answer(
        answer: testAdaptedRecipe(steps: const [AdaptedStep('Alles kochen.')]),
      );
      await pump(tester);

      expect(find.text('Alles kochen.'), findsOneWidget);
      expect(find.text('geändert'), findsNothing);
    });

    testWidgets('no steps: no Zubereitung', (tester) async {
      answer(answer: testAdaptedRecipe(steps: const []));
      await pump(tester);

      expect(find.text('Zubereitung'), findsNothing);
      expect(find.byType(RecipeSteps), findsNothing);
    });

    testWidgets('the note in the bubble beside the Buddy', (tester) async {
      await pump(tester);

      expect(inBubble(find.text(note)), findsOneWidget);
      expect(find.byType(BuddyStage), findsNothing);
    });

    testWidgets('a long note is shown whole', (tester) async {
      final long = List.filled(
        8,
        'Ich hab Honig gegen Ahornsirup getauscht.',
      ).join(' ');
      answer(answer: testAdaptedRecipe(note: long));
      await pump(tester);

      final text = inBubble(find.text(long));
      expect(text, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
    });

    testWidgets('a blank note: no Buddy', (tester) async {
      answer(answer: testAdaptedRecipe(note: ''));
      await pump(tester);

      expect(find.text('Porridge mit Ahornsirup'), findsOneWidget);
      expect(find.byType(AnimatedBuddy), findsNothing);
      expect(find.byType(BuddySpeechBubble), findsNothing);
    });

    testWidgets('every ingredient in the catalog: all checked', (tester) async {
      await pump(tester);

      final checked = find.text(RecipeCopy.allChecked);
      expect(checked, findsOneWidget);
      expect(backgroundOf(tester, checked), AppTheme.gutFeelingGoodSoft);
    });

    testWidgets('an unknown ingredient keeps the check line honest', (
      tester,
    ) async {
      answer(
        answer: testAdaptedRecipe(
          ingredients: const [
            AdaptedIngredient(amount: '50 g', name: 'Haferflocken'),
            AdaptedIngredient(amount: '1 Prise', name: 'Sumach', unknown: true),
          ],
        ),
      );
      await pump(tester);

      final checked = find.text(
        'Mit dem FODMAP-Katalog geprüft. Nicht im Katalog: Sumach',
      );
      expect(checked, findsOneWidget);
      expect(backgroundOf(tester, checked), AppTheme.gutFeelingNeutralSoft);
      expect(find.text(RecipeCopy.allChecked), findsNothing);
      expect(inLine('Sumach', find.byIcon(Icons.help_outline)), findsOne);
      // Said once.
      expect(inLine('Sumach', find.text('nicht im Katalog')), findsOneWidget);
      expect(find.text('nicht im Katalog'), findsOneWidget);
      expect(find.text('unbekannt'), findsNothing);
      expect(inLine('Sumach', find.byIcon(Icons.check)), findsNothing);
      expect(inLine('Haferflocken', find.byIcon(Icons.check)), findsOne);
    });

    testWidgets('a swap to an unknown ingredient says so once', (tester) async {
      final semantics = tester.ensureSemantics();
      answer(
        answer: testAdaptedRecipe(
          ingredients: const [
            AdaptedIngredient(amount: '50 g', name: 'Haferflocken'),
            AdaptedIngredient(
              amount: '1 EL',
              name: 'Dattelsirup',
              replaces: 'Honig',
              unknown: true,
            ),
          ],
        ),
      );
      await pump(tester);

      expect(struck('Honig'), findsOneWidget);
      expect(inLine('Dattelsirup', find.textContaining('getauscht')), findsOne);
      expect(inLine('Dattelsirup', find.byIcon(Icons.help_outline)), findsOne);
      expect(
        inLine('Dattelsirup', find.text('nicht im Katalog')),
        findsOneWidget,
      );
      expect(find.text('nicht im Katalog'), findsOneWidget);
      expect(find.text('unbekannt'), findsNothing);
      expect(
        find.text(
          'Mit dem FODMAP-Katalog geprüft. Nicht im Katalog: '
          'Dattelsirup',
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(line('Dattelsirup')).label,
        'Honig getauscht gegen Dattelsirup, nicht im Katalog',
      );
      semantics.dispose();
    });

    testWidgets('a Histamin user: no ✓, which would read like a verdict', (
      tester,
    ) async {
      await pump(tester, intolerances: const ['Fruktose', 'Histamin']);

      expect(find.text('Porridge mit Ahornsirup'), findsOneWidget);
      expect(find.text('Histamin bitte selbst prüfen'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(
        inLine('Haferflocken', find.byKey(IngredientLineView.neutralKey)),
        findsOne,
      );
      expect(struck('Honig'), findsOneWidget);
    });

    testWidgets('removed ingredients are struck, „weggelassen"', (
      tester,
    ) async {
      answer(answer: testAdaptedRecipe(removed: const ['Zwiebel']));
      await pump(tester);

      expect(struck('Zwiebel'), findsOneWidget);
      expect(inLine('Zwiebel', find.textContaining('weggelassen')), findsOne);
      expect(tester.widget<IngredientLineView>(line('Zwiebel')).removed, true);
      // In line with the others' names.
      expect(
        tester.getTopLeft(line('Zwiebel')).dx,
        tester.getTopLeft(line('Haferflocken')).dx,
      );
      expect(
        tester.getTopLeft(struck('Zwiebel')).dx,
        tester.getTopLeft(inLine('Haferflocken', find.text('Haferflocken'))).dx,
      );
    });

    testWidgets('Original › opens the source in the in-app browser', (
      tester,
    ) async {
      await pump(tester);

      final original = find.text(
        'Original: Porridge mit Honig · Reizdarmblog ›',
      );
      expect(original, findsOneWidget);
      await tester.tapVisible(original);

      expect(launches.urls, [Uri.parse(sourceUrl)]);
      expect(launches.modes, [LaunchMode.inAppBrowserView]);
    });

    testWidgets('without a source link, Original is plain text', (
      tester,
    ) async {
      repo.collection = [original(source: null)];
      await pump(tester);

      final original0 = find.text(
        'Original: Porridge mit Honig · Reizdarmblog',
      );
      expect(original0, findsOneWidget);
      expect(find.textContaining('›'), findsNothing);
      await tester.tapVisible(original0);
      expect(launches.urls, isEmpty);
    });

    testWidgets('the original is there with the first result frame', (
      tester,
    ) async {
      final collection = Completer<List<Recipe>>();
      final gated = _GatedCollection(collection.future)
        ..collection = [original()];
      repo = gated;
      final reply = Completer<AdaptedRecipe>();
      repo.onAdapt = (_) => reply.future;
      await pump(tester);
      expect(gated.collectionFetches, 1);

      collection.complete([original()]);
      await tester.pumpAndSettle();
      reply.complete(testAdaptedRecipe());
      // The first frame that shows the answer.
      final title = find.text('Porridge mit Ahornsirup');
      for (var i = 0; i < 5 && title.evaluate().isEmpty; i++) {
        await tester.pump();
      }

      expect(title, findsOneWidget);
      expect(find.text('10 Min · 2 Portionen'), findsOneWidget);
      expect(find.text('für 2 Portionen'), findsOneWidget);
      expect(
        tester
            .widget<RecipePlaceholder>(find.byType(RecipePlaceholder))
            .mealType,
        MealType.breakfast,
      );
    });

    testWidgets('the original gone from the collection: no meta, no Original', (
      tester,
    ) async {
      repo.collection = [];
      await pump(tester);

      expect(find.text('Porridge mit Ahornsirup'), findsOneWidget);
      expect(find.byKey(RecipePlaceholder.placeholderKey), findsOneWidget);
      expect(find.textContaining('Original'), findsNothing);
      expect(find.textContaining('Portion'), findsNothing);
      expect(find.text('Zutaten'), findsOneWidget);
    });
  });

  group('failure', () {
    final cases = {
      AdaptFailure.later:
          'Ich bin gerade ausgelastet. Versuch es bitte später nochmal.',
      AdaptFailure.failed:
          'Das hat gerade nicht geklappt. Versuch es bitte nochmal.',
      AdaptFailure.nothingToAdapt: 'Hier muss ich für dich nichts tauschen.',
      AdaptFailure.cannotJudge:
          'Ob ich hier etwas tauschen muss, kann ich nicht prüfen: Mir fehlen '
          'Angaben zu den Zutaten.',
      AdaptFailure.notFound: 'Dieses Rezept kann ich nicht finden.',
    };

    for (final MapEntry(key: failure, value: message) in cases.entries) {
      testWidgets("each failure's message: ${failure.name}", (tester) async {
        answer(failure: failure);
        await pump(tester);

        expect(RecipeCopy.adaptFailed(failure), message);
        expect(inBubble(find.text(message)), findsOneWidget);
        expect(moodOf(tester), BuddyMood.empathetic);
        expect(find.byType(BuddyStage), findsNothing);
        expect(find.byKey(AdaptRecipeScreen.saveKey), findsNothing);
        final retryable =
            failure == AdaptFailure.later || failure == AdaptFailure.failed;
        expect(
          find.byKey(AdaptRecipeScreen.retryKey),
          retryable ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Nochmal versuchen'),
          retryable ? findsOneWidget : findsNothing,
        );
        if (!retryable) {
          expect(find.text('Zurück zum Rezept'), findsOneWidget);
          // Nothing that reads like „passt (schon zu dir)".
          expect(find.textContaining('passt'), findsNothing);

          await tester.tap(find.text('Zurück zum Rezept'));
          await tester.pumpAndSettle();
          expect(find.text('page:/collection/recipe-1'), findsOneWidget);
        }
      });
    }

    testWidgets('retry calls again', (tester) async {
      answer(failure: AdaptFailure.later);
      await pump(tester);
      expect(repo.adaptCalls, 1);

      answer();
      await tester.tap(find.byKey(AdaptRecipeScreen.retryKey));
      await tester.pumpAndSettle();

      expect(repo.adaptCalls, 2);
      expect(find.byKey(AdaptRecipeScreen.retryKey), findsNothing);
      expect(find.text('Porridge mit Ahornsirup'), findsOneWidget);
    });

    testWidgets('retry shows the loading Buddy again', (tester) async {
      answer(failure: AdaptFailure.failed);
      await pump(tester);

      final reply = Completer<AdaptedRecipe>();
      repo.onAdapt = (_) => reply.future;
      await tester.tap(find.byKey(AdaptRecipeScreen.retryKey));
      await tester.pumpAndSettle();

      expect(inBubble(find.text(loadingLine)), findsOneWidget);
      expect(moodOf(tester), BuddyMood.zen);
      expect(find.byKey(AdaptRecipeScreen.retryKey), findsNothing);

      reply.complete(testAdaptedRecipe());
      await tester.pumpAndSettle();
      expect(find.text('Porridge mit Ahornsirup'), findsOneWidget);
    });
  });

  group('save', () {
    testWidgets('createAdapted reaches the fake with the amounts, steps and '
        'origin; the button opens the saved recipe', (tester) async {
      await pump(tester);
      expect(inSave(find.text('In Meine Rezepte speichern')), findsOneWidget);

      await tester.tap(find.byKey(AdaptRecipeScreen.saveKey));
      await tester.pumpAndSettle();

      final saved = (await userRecipes.fetchForUser(testUserId)).single;
      expect(saved.id, 'rec-1');
      expect(saved.title, 'Porridge mit Ahornsirup');
      expect(saved.ingredients, ['Haferflocken', 'Haferdrink', 'Ahornsirup']);
      expect(saved.ingredientAmounts, ['50 g', '200 ml', '1 EL']);
      expect(saved.instructions, [
        'Haferflocken im Haferdrink aufkochen.',
        'Mit Ahornsirup süßen.',
      ]);
      expect(saved.adaptedFromRecipeId, 'recipe-1');

      expect(inSave(find.text('In Meine Rezepte gespeichert')), findsOneWidget);
      expect(inSave(find.byIcon(Icons.check)), findsOneWidget);
      expect(find.text(RecipeCopy.adaptSaveFailed), findsNothing);

      await tester.tap(find.byKey(AdaptRecipeScreen.saveKey));
      await tester.pumpAndSettle();

      expect(find.text('page:/recipe/rec-1'), findsOneWidget);
      // Saved once.
      expect(await userRecipes.fetchForUser(testUserId), hasLength(1));
    });

    testWidgets('loading while saving', (tester) async {
      final gate = Completer<void>();
      userRecipes = _GatedUserRecipes(gate.future);
      await pump(tester);

      await tester.tap(find.byKey(AdaptRecipeScreen.saveKey));
      await tester.pump();

      expect(inSave(find.byType(CircularProgressIndicator)), findsOneWidget);
      await tester.tap(find.byKey(AdaptRecipeScreen.saveKey));
      await tester.pump();

      gate.complete();
      await tester.pumpAndSettle();
      expect(inSave(find.text('In Meine Rezepte gespeichert')), findsOneWidget);
      expect(await userRecipes.fetchForUser(testUserId), hasLength(1));
    });

    testWidgets('a backend that keeps no steps: saved, the steps said to be '
        'left out', (tester) async {
      userRecipes = FakeUserRecipeRepository()..newColumns = false;
      await pump(tester);

      await tester.tap(find.byKey(AdaptRecipeScreen.saveKey));
      await tester.pumpAndSettle();

      expect(find.text(RecipeCopy.stepsNotSaved), findsOneWidget);
      expect(inSave(find.text('In Meine Rezepte gespeichert')), findsOneWidget);
      expect(find.text(RecipeCopy.adaptSaveFailed), findsNothing);
    });

    testWidgets('steps kept: nothing said', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(AdaptRecipeScreen.saveKey));
      await tester.pumpAndSettle();

      expect(find.text(RecipeCopy.stepsNotSaved), findsNothing);
    });

    testWidgets('save fails → SnackBar', (tester) async {
      userRecipes = _FailingUserRecipes();
      await pump(tester);

      await tester.tap(find.byKey(AdaptRecipeScreen.saveKey));
      await tester.pumpAndSettle();

      expect(find.text(RecipeCopy.adaptSaveFailed), findsOneWidget);
      expect(inSave(find.text('In Meine Rezepte speichern')), findsOneWidget);
      expect(find.text('page:/recipe/rec-1'), findsNothing);
    });
  });

  testWidgets('Als Essen eintragen pushes the adapted names', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(AdaptRecipeScreen.logKey));
    await tester.pumpAndSettle();

    expect(find.text('page:${RoutePaths.mealTracker}'), findsOneWidget);
    final prefill = pushed[RoutePaths.mealTracker];
    expect(prefill, isA<MealPrefill>());
    prefill as MealPrefill;
    expect(prefill.title, 'Porridge mit Ahornsirup');
    expect(prefill.ingredients, ['Haferflocken', 'Haferdrink', 'Ahornsirup']);
    expect(prefill.imageUrl, isNull);
  });

  group('fits 375×667 at text scale 1.3', () {
    setUp(() {
      answer(
        answer: testAdaptedRecipe(
          ingredients: [
            for (var i = 0; i < 7; i++)
              AdaptedIngredient(amount: '${i + 1}00 g', name: 'Zutat $i'),
            const AdaptedIngredient(
              amount: '1 EL',
              name: 'Ahornsirup',
              replaces: 'Honig',
            ),
          ],
          removed: const ['Zwiebel'],
          steps: [
            for (var i = 0; i < 6; i++)
              AdaptedStep(
                'Schritt ${i + 1}: alles gut verrühren und kochen.',
                changed: i.isEven,
              ),
          ],
        ),
      );
    });

    Future<List<String>> pumpSmall(
      WidgetTester tester, {
      bool requested = true,
    }) async {
      tester.view
        ..physicalSize = const Size(375, 667)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      return collectFlutterErrors(
        () => pump(tester, requested: requested, textScale: 1.3),
      );
    }

    testWidgets('the result', (tester) async {
      final errors = await pumpSmall(tester);

      expect(find.text('Porridge mit Ahornsirup'), findsOneWidget);
      expect(find.byKey(AdaptRecipeScreen.saveKey), findsOneWidget);
      expect(find.byKey(AdaptRecipeScreen.logKey), findsOneWidget);
      expect(verticalOverflows(errors), isEmpty);
      expect(errors, isEmpty);

      // Saved, the button says so with its check.
      final saveErrors = await collectFlutterErrors(() async {
        await tester.tap(find.byKey(AdaptRecipeScreen.saveKey));
        await tester.pumpAndSettle();
      });
      expect(inSave(find.text('In Meine Rezepte gespeichert')), findsOneWidget);
      expect(saveErrors, isEmpty);
    });

    testWidgets('the question', (tester) async {
      final errors = await pumpSmall(tester, requested: false);

      expect(find.byKey(AdaptRecipeScreen.startKey), findsOneWidget);
      expect(errors, isEmpty);
    });

    testWidgets('a failure', (tester) async {
      answer(failure: AdaptFailure.cannotJudge);
      final errors = await pumpSmall(tester);

      expect(find.text('Zurück zum Rezept'), findsOneWidget);
      expect(errors, isEmpty);
    });
  });
}

/// The collection arrives with [arrival].
class _GatedCollection extends FakeRecipeRepository {
  _GatedCollection(this.arrival);

  final Future<List<Recipe>> arrival;

  @override
  Future<List<Recipe>> fetchCollection() {
    collectionFetches++;
    return arrival;
  }
}

/// Saves only once [gate] opens.
class _GatedUserRecipes extends FakeUserRecipeRepository {
  _GatedUserRecipes(this.gate);

  final Future<void> gate;

  @override
  Future<UserRecipe> create({
    required String userId,
    required String title,
    required List<String> ingredients,
    String? imageUrl,
    List<String> instructions = const [],
    List<String?>? ingredientAmounts,
    String? adaptedFromRecipeId,
  }) async {
    await gate;
    return super.create(
      userId: userId,
      title: title,
      ingredients: ingredients,
      imageUrl: imageUrl,
      instructions: instructions,
      ingredientAmounts: ingredientAmounts,
      adaptedFromRecipeId: adaptedFromRecipeId,
    );
  }
}

/// Every save fails.
class _FailingUserRecipes extends FakeUserRecipeRepository {
  @override
  Future<UserRecipe> create({
    required String userId,
    required String title,
    required List<String> ingredients,
    String? imageUrl,
    List<String> instructions = const [],
    List<String?>? ingredientAmounts,
    String? adaptedFromRecipeId,
  }) async => throw StateError('offline');
}
