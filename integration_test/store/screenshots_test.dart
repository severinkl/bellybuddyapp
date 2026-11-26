// Store screenshots: the app on demo data (fakes, no backend), one screen per
// shot. The test prints `SHOT:<name>` and holds still for a few seconds; the
// host script captures the simulator/emulator screen meanwhile.
//
// Not a CI test (CI runs integration_test/*_test.dart, not this folder): run
// it with tool/store_screenshots.sh. Devices for the stores' sizes: iPhone 17
// Pro (1206 x 2622), iPad Pro 13" (2064 x 2752), an Android emulator at
// 1080 x 1920 (Play wants 9:16).
// ignore_for_file: avoid_print

import 'package:belly_buddy/app.dart';
import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/config/splash_screen_config.dart';
import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/models/insight_source.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/splash_screen_provider.dart';
import 'package:belly_buddy/providers/upgrade_gate_provider.dart';
import 'package:belly_buddy/providers/user_recipes_provider.dart';
import 'package:belly_buddy/repositories/repositories.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/dashboard/dashboard_screen.dart';
import 'package:belly_buddy/services/entry_query_service.dart';
import 'package:belly_buddy/widgets/common/bb_slider.dart';
import 'package:belly_buddy/models/fodmap_flags.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../test/helpers/ambient_animations.dart';
import '../../test/helpers/fakes.dart';
import '../../test/helpers/fixtures.dart';

/// Photos of the collection's recipes (Unsplash), as the admin shows them.
String _photo(String id) =>
    'https://images.unsplash.com/photo-$id?w=1200&q=80&auto=format&fit=crop';

final _oats = _photo('1517673400267-0251440c45dc');
final _chickenVeg = _photo('1532550907401-a500c9a57435');
final _quinoaBowl = _photo('1512621776951-a57141f2eefd');
final _pumpkinSoup = _photo('1476718406336-bb5a9690ee2a');
final _salmonRice = _photo('1467003909585-2f8a72700288');
final _pancakes = _photo('1567620905732-2d1ec7ab7445');
final _riceSoup = _photo('1547592166-23ac45744acd');

DateTime _today(int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

DateTime _daysAgo(int days, int hour) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - days, hour);
}

final _meals = [
  testMealEntry(
    id: 'meal-breakfast',
    trackedAt: _today(8, 10),
    title: 'Haferflocken mit Banane',
    ingredients: ['Haferflocken', 'Banane', 'Laktosefreie Milch', 'Zimt'],
    imageUrl: _oats,
  ),
  testMealEntry(
    id: 'meal-lunch',
    trackedAt: _today(12, 40),
    title: 'Gedünstetes Gemüse mit Hühnchen',
    ingredients: [
      'Hühnchen',
      'Brokkoli',
      'Karotten',
      'Zucchini',
      'Zwiebel',
      'Reis',
    ],
    imageUrl: _chickenVeg,
  ),
];

final _todayResult = EntryQueryResult(
  meals: _meals,
  toiletEntries: [testToiletEntry(id: 'toilet-1', trackedAt: _today(9, 5))],
  gutFeelings: [
    testGutFeelingEntry(
      id: 'gut-1',
      trackedAt: _today(14, 30),
      bloating: 1,
      gas: 1,
      cramps: 0,
      fullness: 2,
    ),
  ],
  drinks: [
    testDrinkEntry(id: 'd1', trackedAt: _today(7, 45), amountMl: 500),
    testDrinkEntry(
      id: 'd2',
      trackedAt: _today(10, 30),
      drinkId: 'tea-id',
      drinkName: 'Kräutertee',
      amountMl: 250,
    ),
    testDrinkEntry(id: 'd3', trackedAt: _today(13, 0), amountMl: 330),
  ],
);

/// Two weeks past the unlock: Zwiebel before 4 of 5 hard days.
InsightSource _insightSource() {
  const hardDaysAgo = [2, 4, 6, 8, 10];
  const goodDaysAgo = [1, 3, 5, 7, 9, 11, 12, 13];
  final gutFeelings = [
    for (final d in hardDaysAgo)
      testGutFeelingEntry(
        id: 'gut-h$d',
        trackedAt: _daysAgo(d, 15),
        bloating: 5,
        gas: 4,
        cramps: 3,
        fullness: 4,
      ),
    for (final d in goodDaysAgo)
      testGutFeelingEntry(
        id: 'gut-g$d',
        trackedAt: _daysAgo(d, 15),
        bloating: 1,
        gas: 1,
        cramps: 0,
        fullness: 1,
      ),
  ];
  return InsightSource(
    meals: [
      for (final d in hardDaysAgo.take(4))
        InsightMeal(
          trackedAt: _daysAgo(d, 12),
          ingredients: const ['Zwiebel', 'Reis', 'Hühnchen'],
        ),
      for (final d in goodDaysAgo)
        InsightMeal(
          trackedAt: _daysAgo(d, 12),
          ingredients: const ['Reis', 'Karotten', 'Hühnchen'],
        ),
    ],
    gutFeelings: gutFeelings,
    activityTimes: [for (final g in gutFeelings) g.trackedAt],
  );
}

RecipeIngredient _l(String name, String amount, [FodmapFlags? f]) =>
    testLine(name, amount: amount, fodmaps: f ?? const FodmapFlags());

Recipe _recipe(
  String id,
  String title,
  String image,
  List<RecipeIngredient> lines, {
  String cookTime = '25 Min',
  int servings = 2,
  List<MealType> mealTypes = const [MealType.lunch, MealType.dinner],
  Set<String> dietTags = const {'vegetarisch'},
  List<String> instructions = const [],
}) => Recipe(
  id: id,
  title: title,
  cookTime: cookTime,
  servings: servings,
  imageUrl: image,
  mealTypes: mealTypes,
  dietTags: dietTags,
  instructions: instructions,
  ingredients: [
    for (final (i, line) in lines.indexed)
      testLine(
        line.name,
        position: i,
        amount: line.amount,
        fodmaps: line.fodmaps ?? const FodmapFlags(),
      ),
  ],
);

List<Recipe> _recipes() => [
  _recipe(
    'r-quinoa',
    'Quinoa-Gemüse-Bowl',
    _quinoaBowl,
    [
      _l('Quinoa', '150 g'),
      _l('Karotten', '2'),
      _l('Gurke', '1/2'),
      _l('Feldsalat', '1 Handvoll'),
      _l('Kürbiskerne', '2 EL'),
      _l('Olivenöl', '2 EL'),
    ],
    cookTime: '20 Min',
    dietTags: const {'vegan', 'vegetarisch'},
    instructions: const [
      'Quinoa gründlich waschen und 15 Minuten köcheln lassen.',
      'Karotten raspeln, Gurke in Scheiben schneiden.',
      'Alles anrichten, mit Kürbiskernen und Olivenöl vollenden.',
    ],
  ),
  _recipe(
    'r-pumpkin',
    'Kürbissuppe',
    _pumpkinSoup,
    [
      _l('Hokkaido-Kürbis', '600 g'),
      _l('Kartoffeln', '200 g'),
      _l('Ingwer', '1 Stück'),
      _l('Kokosmilch', '100 ml'),
    ],
    dietTags: const {'vegan', 'vegetarisch'},
  ),
  _recipe('r-salmon', 'Gedämpfter Lachs mit Reis', _salmonRice, [
    _l('Lachs', '2 Filets'),
    _l('Reis', '150 g'),
    _l('Zucchini', '1'),
  ], dietTags: const {}),
  _recipe(
    'r-pancakes',
    'Buchweizen-Pfannkuchen',
    _pancakes,
    [
      _l('Buchweizenmehl', '150 g'),
      _l('Eier', '2'),
      _l('Laktosefreie Milch', '250 ml'),
      _l('Heidelbeeren', '80 g'),
    ],
    cookTime: '15 Min',
    mealTypes: const [MealType.breakfast],
  ),
  _recipe(
    'r-ricesoup',
    'Gemüse-Reis-Suppe',
    _riceSoup,
    [_l('Reis', '80 g'), _l('Karotten', '2'), _l('Petersilie', '1 Bund')],
    dietTags: const {'vegan', 'vegetarisch'},
  ),
];

ProviderScope _demoApp() {
  disableAmbientAnimationsForTests();

  final profileRepo = FakeProfileRepository()
    ..seedProfile(
      testUserProfile(
        birthYear: 1994,
        gender: 'female',
        height: 168,
        weight: 62,
        symptoms: ['Blähungen', 'Bauchschmerzen', 'Völlegefühl'],
        intolerances: ['Laktose', 'Fruktose'],
        weeklyTipsEnabled: true,
      ),
    );

  final buddyRepo = FakeBuddyRepository();
  buddyRepo.store[testUserId] = BuddyState(
    userId: testUserId,
    streakGoal: 14,
    onboardingCompletedAt: _daysAgo(14, 9),
  );

  final today = DateTime.now();
  final entryRepo = FakeEntryRepository()
    ..seedResult(_todayResult)
    ..seedActivityDays({
      for (var i = 1; i <= 13; i++)
        DateTime(today.year, today.month, today.day - i),
    })
    ..insightSource = _insightSource();

  final drinkRepo = FakeDrinkRepository()
    ..seedDrinks([
      testDrink(),
      testDrink(id: 'tea-id', name: 'Kräutertee'),
      testDrink(id: 'coffee-id', name: 'Kaffee'),
      testDrink(id: 'juice-id', name: 'Orangensaft'),
    ]);

  final recipeRepo = FakeRecipeRepository()..collection = _recipes();

  final recommendationRepo = FakeRecommendationRepository(
    sets: [
      testRecommendation(
        id: 'tips-1',
        summary:
            'Diese Woche lief es meist gut. An schweren Tagen war oft Zwiebel '
            'dabei – probier eine Alternative.',
        createdAt: _daysAgo(1, 8),
        recommendations: [
          testRecommendationItem(
            ingredient: 'Zwiebel',
            alternative: 'Schnittlauch',
            reason:
                'Zwiebel enthält viele Fructane. Schnittlauch bringt ähnliches '
                'Aroma mit weniger FODMAPs.',
            focus: true,
          ),
          testRecommendationItem(
            ingredient: 'Knoblauch',
            alternative: 'Knoblauchöl',
            reason:
                'Die Fructane gehen nicht ins Öl über – der Geschmack schon.',
          ),
          testRecommendationItem(
            type: 'try',
            ingredient: 'Quinoa',
            alternative: null,
            reason: 'Sättigt lange und ist arm an FODMAPs.',
            recipeId: 'r-quinoa',
            recipeTitle: 'Quinoa-Gemüse-Bowl',
          ),
        ],
      ),
    ],
  );

  final user = User.fromJson({
    'id': testUserId,
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': _daysAgo(14, 9).toIso8601String(),
  });

  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => user),
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(signedIn: true),
      ),
      profileRepositoryProvider.overrideWithValue(profileRepo),
      entryRepositoryProvider.overrideWithValue(entryRepo),
      drinkRepositoryProvider.overrideWithValue(drinkRepo),
      ingredientRepositoryProvider.overrideWithValue(
        FakeIngredientRepository(),
      ),
      recipeRepositoryProvider.overrideWithValue(recipeRepo),
      userRecipeRepositoryProvider.overrideWithValue(
        FakeUserRecipeRepository(),
      ),
      recommendationRepositoryProvider.overrideWithValue(recommendationRepo),
      mealMediaRepositoryProvider.overrideWithValue(FakeMealMediaRepository()),
      notificationRepositoryProvider.overrideWithValue(
        FakeNotificationRepository(),
      ),
      buddyRepositoryProvider.overrideWithValue(buddyRepo),
      splashConfigProvider.overrideWithValue(SplashConfig.test),
      upgradeDecisionProvider.overrideWith(
        (_) => Future.value(UpgradeDecision.ok),
      ),
    ],
    child: const BellyBuddyApp(),
  );
}

/// Lets images load and the screen come to rest, then signals the host.
Future<void> _shot(WidgetTester tester, String name) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  print('SHOT:$name');
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void _go(WidgetTester tester, String path) {
  GoRouter.of(tester.element(find.byType(Navigator).first)).go(path);
}

void _push(WidgetTester tester, String path) {
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyNotificationModalShown: true,
    });

    await tester.pumpWidget(_demoApp());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(DashboardScreen).evaluate().isNotEmpty) break;
    }
    await _shot(tester, '01_home');

    _push(tester, RoutePaths.mealTrackerEditFor('meal-lunch'));
    await _shot(tester, '02_meal');
    _go(tester, RoutePaths.dashboard);

    _push(tester, RoutePaths.gutFeelingTracker);
    await _settle(tester);
    // Blähbauch a little, Blähungen a little, no Krämpfe, Völlegefühl some.
    const levels = [0.5, 0.25, 0.0, 0.5];
    final sliders = find.byType(BbSlider);
    for (var i = 0; i < levels.length; i++) {
      final rect = tester.getRect(sliders.at(i));
      await tester.tapAt(
        Offset(rect.left + 12 + (rect.width - 24) * levels[i], rect.center.dy),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
    await _shot(tester, '03_gut_feeling');
    _go(tester, RoutePaths.dashboard);

    _go(tester, RoutePaths.diary);
    await _shot(tester, '04_diary');

    _push(tester, RoutePaths.patterns);
    await _shot(tester, '05_patterns');
    _go(tester, RoutePaths.discover);

    _push(tester, RoutePaths.recommendations);
    await _shot(tester, '06_tips');
    _go(tester, RoutePaths.discover);

    await _shot(tester, '07_discover');

    _push(tester, RoutePaths.collectionRecipeFor('r-quinoa'));
    await _shot(tester, '08_recipe');
    _go(tester, RoutePaths.discover);

    print('SHOTS:DONE');
  });
}
