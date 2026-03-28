// ignore_for_file: invalid_use_of_internal_member
import 'package:belly_buddy/config/splash_screen_config.dart';
import 'package:belly_buddy/providers/splash_screen_provider.dart';
import 'package:belly_buddy/screens/trackers/meal/meal_tracker_screen.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/app.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/drink_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/ingredient_repository.dart';
import 'package:belly_buddy/repositories/meal_media_repository.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';

import '../test/helpers/fakes.dart';
import '../test/helpers/fixtures.dart';

late FakeProfileRepository _fakeProfileRepo;
late FakeEntryRepository _fakeEntryRepo;

List<Override> _buildOverrides() => [
  currentUserIdProvider.overrideWithValue(testUserId),
  authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
  profileRepositoryProvider.overrideWithValue(_fakeProfileRepo),
  entryRepositoryProvider.overrideWithValue(_fakeEntryRepo),
  drinkRepositoryProvider.overrideWithValue(FakeDrinkRepository()),
  ingredientRepositoryProvider.overrideWithValue(FakeIngredientRepository()),
  recipeRepositoryProvider.overrideWithValue(FakeRecipeRepository()),
  recommendationRepositoryProvider.overrideWithValue(
    FakeRecommendationRepository(),
  ),
  mealMediaRepositoryProvider.overrideWithValue(FakeMealMediaRepository()),
  notificationRepositoryProvider.overrideWithValue(
    FakeNotificationRepository(),
  ),
  splashConfigProvider.overrideWithValue(SplashConfig.test),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _fakeProfileRepo = FakeProfileRepository()..seedProfile(testUserProfile());
    _fakeEntryRepo = FakeEntryRepository();
  });

  testWidgets(
    'can navigate to meal tracker from dashboard and should see the title',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _buildOverrides(),
          child: const BellyBuddyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // should find the meal tracker button on the dashboard and tap it
      final mealTrackerButton = find.byKey(BbBottomNav.centerButtonKey);
      expect(mealTrackerButton, findsOneWidget);
      await tester.tap(mealTrackerButton);
      await tester.pumpAndSettle();

      // should navigate to the meal tracker screen and find the title
      expect(find.byKey(MealTrackerScreen.mealTrackerTitleKey), findsOneWidget);
    },
  );
}
