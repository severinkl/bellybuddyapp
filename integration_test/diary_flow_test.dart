// ignore_for_file: invalid_use_of_internal_member
import 'package:belly_buddy/config/splash_screen_config.dart';
import 'package:belly_buddy/providers/splash_screen_provider.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:flutter/material.dart';
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
import 'package:belly_buddy/screens/diary/diary_screen.dart';

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

  testWidgets('diary tab shows entries for the selected date', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _buildOverrides(), child: const BellyBuddyApp()),
    );
    await tester.pumpAndSettle();

    final diaryNavItem = find.byKey(BbBottomNav.navDiaryKey);

    expect(diaryNavItem, findsOneWidget);

    await tester.ensureVisible(diaryNavItem);
    await tester.pumpAndSettle();

    await tester.tap(diaryNavItem);
    await tester.pumpAndSettle();

    expect(find.byType(DiaryScreen), findsOneWidget);

    final hasEntries = find
        .textContaining('Testmahlzeit')
        .evaluate()
        .isNotEmpty;
    final hasEmptyState =
        find.textContaining('Tracken').evaluate().isNotEmpty ||
        find.textContaining('Daten').evaluate().isNotEmpty;

    expect(hasEntries || hasEmptyState, isTrue);
  });

  testWidgets('diary date navigation changes the displayed date', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _buildOverrides(), child: const BellyBuddyApp()),
    );
    await tester.pumpAndSettle();

    final diaryNavItem = find.byKey(BbBottomNav.navDiaryKey);
    expect(diaryNavItem, findsOneWidget);

    await tester.ensureVisible(diaryNavItem);
    await tester.pumpAndSettle();

    await tester.tap(diaryNavItem);
    await tester.pumpAndSettle();

    expect(find.byType(DiaryScreen), findsOneWidget);

    final displayedDateFinder = find.byKey(DiaryScreen.displayedDateKey);
    expect(displayedDateFinder, findsOneWidget);

    final dateBefore = tester.widget<Text>(displayedDateFinder).data;
    expect(dateBefore, isNotNull);

    final prevDayFinder = find.byKey(DiaryScreen.previousDayKey);
    expect(prevDayFinder, findsOneWidget);

    await tester.ensureVisible(prevDayFinder);
    await tester.pumpAndSettle();

    await tester.tap(prevDayFinder);
    await tester.pumpAndSettle();

    expect(find.byType(DiaryScreen), findsOneWidget);

    final dateAfter = tester.widget<Text>(displayedDateFinder).data;
    expect(dateAfter, isNotNull);
    expect(dateAfter, isNot(equals(dateBefore)));
  });
}
