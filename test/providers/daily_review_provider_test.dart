import 'package:belly_buddy/models/ingredient_suggestion_group.dart';
import 'package:belly_buddy/models/meal_entry.dart';
import 'package:belly_buddy/models/replacement_ingredient.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/providers/alternative_choices_provider.dart';
import 'package:belly_buddy/providers/buddy_onboarding_gate_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/daily_review_provider.dart';
import 'package:belly_buddy/providers/diary_provider.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/providers/ingredient_suggestion_provider.dart';
import 'package:belly_buddy/providers/minute_provider.dart';
import 'package:belly_buddy/providers/plus_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fixtures.dart';
import '../helpers/riverpod_helpers.dart';

final _today = DateTime(2026, 11, 27);
final _yesterday = DateTime(2026, 11, 26);

DateTime _at(DateTime day, int h, [int m = 0]) =>
    DateTime(day.year, day.month, day.day, h, m);

/// Wall clock in the UTC slot, as `tracked_at` is read.
DateTime _wall(DateTime day, int h) =>
    DateTime.utc(day.year, day.month, day.day, h);

MealEntry _meal(String id, DateTime day) =>
    testMealEntry(id: id, trackedAt: _wall(day, 12));

DiaryEntry _diaryMeal(MealEntry m) => DiaryEntry(
  id: m.id,
  type: DiaryEntryType.meal,
  trackedAt: m.trackedAt,
  title: m.title,
  subtitle: '',
  data: MealDiaryData(m),
);

IngredientSuggestionGroup _group(String mealId, DateTime day) =>
    IngredientSuggestionGroup(
      ingredientId: 'onion',
      ingredientName: 'Zwiebel',
      mealCount: 1,
      isNew: false,
      suggestionIds: const ['s1'],
      meals: [MealDetail(id: mealId, title: mealId, trackedAt: _wall(day, 12))],
      replacements: const [
        ReplacementIngredient(id: 'chive', name: 'Schnittlauch'),
      ],
    );

class _Minute extends MinuteNotifier {
  _Minute(this._initial);
  final DateTime _initial;

  @override
  DateTime build() => _initial;

  void set(DateTime now) => state = now;
}

class _Profile extends ProfileNotifier {
  _Profile(this._initial);
  final UserProfile _initial;

  @override
  AsyncValue<UserProfile?> build() => AsyncValue.data(_initial);

  void set(UserProfile p) => state = AsyncValue.data(p);
}

class _Entries extends EntriesNotifier {
  _Entries(this._initial);
  final EntriesState _initial;

  @override
  EntriesState build() => _initial;
}

class _Suggestions extends IngredientSuggestionNotifier {
  _Suggestions(this._initial);
  final AsyncValue<List<IngredientSuggestionGroup>> _initial;

  @override
  AsyncValue<List<IngredientSuggestionGroup>> build() => _initial;

  void set(AsyncValue<List<IngredientSuggestionGroup>> v) => state = v;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late SwitchableUserId user;

  ProviderContainer container({
    required DateTime now,
    List<MealEntry> todayMeals = const [],
    DateTime? entriesDay,
    List<MealEntry> diaryMeals = const [],
    UserProfile? profile,
    AsyncValue<List<IngredientSuggestionGroup>> groups = const AsyncData([]),
    bool onboarding = false,
    bool plusLocked = false,
    bool? seamLocked,
  }) {
    user = SwitchableUserId('a');
    final c = createContainer(
      overrides: [
        user.override,
        buddyClockProvider.overrideWithValue(() => now),
        minuteProvider.overrideWith(() => _Minute(now)),
        profileProvider.overrideWith(
          () => _Profile(profile ?? testUserProfile()),
        ),
        entriesProvider.overrideWith(
          () => _Entries(
            EntriesState(meals: todayMeals, day: entriesDay ?? _today),
          ),
        ),
        diaryEntriesProvider.overrideWith(
          (ref, day) async => [
            for (final m in diaryMeals)
              if (m.trackedAt.day == day.day) _diaryMeal(m),
          ],
        ),
        ingredientSuggestionProvider.overrideWith(() => _Suggestions(groups)),
        chosenAlternativesProvider.overrideWithValue(const {}),
        buddyOnboardingRequiredProvider.overrideWithValue(onboarding),
        plusLockedProvider.overrideWithValue(plusLocked),
        if (seamLocked != null)
          dailyReviewAlternativeLockedProvider.overrideWithValue(seamLocked),
      ],
    );
    c.listen(dailyReviewProvider, (_, _) {});
    return c;
  }

  /// Lets the prefs read and the diary fetch land.
  Future<void> settle(ProviderContainer c) async {
    await c.read(dailyReviewClosedProvider.future);
    await Future<void>.delayed(Duration.zero);
  }

  void tick(ProviderContainer c, DateTime now) =>
      (c.read(minuteProvider.notifier) as _Minute).set(now);

  test(
    'at 19:30 with one meal today → review for today; with no meal → null',
    () async {
      final c = container(
        now: _at(_today, 19, 30),
        todayMeals: [_meal('m1', _today)],
      );
      await settle(c);
      final review = c.read(dailyReviewProvider)!;
      expect(review.day.yesterday, isFalse);
      expect(review.day.day, _today);
      expect(review.meals, 1);

      final empty = container(now: _at(_today, 19, 30));
      await settle(empty);
      expect(empty.read(openReviewDayProvider), isNotNull);
      expect(empty.read(dailyReviewProvider), isNull);
    },
  );

  test(
    'at 08:00 with a meal yesterday → yesterday review from the diary day',
    () async {
      final c = container(
        now: _at(_today, 8),
        diaryMeals: [_meal('y1', _yesterday), _meal('y2', _yesterday)],
      );
      await settle(c);
      final review = c.read(dailyReviewProvider)!;
      expect(review.day.yesterday, isTrue);
      expect(review.day.day, _yesterday);
      expect(review.meals, 2);
    },
  );

  test('the minute ticks from 19:29 to 19:30 → review appears without other '
      'changes', () async {
    final c = container(
      now: _at(_today, 19, 29),
      todayMeals: [_meal('m1', _today)],
    );
    await settle(c);
    expect(c.read(dailyReviewProvider), isNull);
    tick(c, _at(_today, 19, 30));
    expect(c.read(dailyReviewProvider)?.day.day, _today);
  });

  test("23:59 → 00:00: today's review becomes yesterday's", () async {
    final meal = _meal('m1', _yesterday);
    final c = container(
      now: _at(_yesterday, 23, 59),
      entriesDay: _yesterday,
      todayMeals: [meal],
      diaryMeals: [meal],
    );
    await settle(c);
    final before = c.read(dailyReviewProvider)!;
    expect(before.day.yesterday, isFalse);
    expect(before.day.day, _yesterday);

    tick(c, _at(_today, 0));
    await settle(c);
    final after = c.read(dailyReviewProvider)!;
    expect(after.day.yesterday, isTrue);
    expect(after.day.day, _yesterday);
    expect(after.meals, 1);
  });

  test('close(today) → null for the rest of today; user B on the same device '
      'still sees theirs', () async {
    final c = container(
      now: _at(_today, 20),
      todayMeals: [_meal('m1', _today)],
    );
    await settle(c);
    expect(c.read(dailyReviewProvider), isNotNull);

    await c.read(dailyReviewClosedProvider.notifier).close(_today);
    expect(c.read(dailyReviewProvider), isNull);
    tick(c, _at(_today, 23, 59));
    expect(c.read(dailyReviewProvider), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('daily_review_closed_a'), '2026-11-27');

    user.set(c, 'b');
    await settle(c);
    expect(c.read(dailyReviewProvider)?.day.day, _today);

    user.set(c, 'a');
    await settle(c);
    expect(c.read(dailyReviewProvider), isNull);
  });

  test('profile time changed to 21:00 at 20:00 → null until 21:00', () async {
    final c = container(
      now: _at(_today, 20),
      todayMeals: [_meal('m1', _today)],
    );
    await settle(c);
    expect(c.read(dailyReviewProvider), isNotNull);

    (c.read(profileProvider.notifier) as _Profile).set(
      testUserProfile(dailyReviewTime: '21:00'),
    );
    expect(c.read(dailyReviewProvider), isNull);
    tick(c, _at(_today, 20, 59));
    expect(c.read(dailyReviewProvider), isNull);
    tick(c, _at(_today, 21));
    expect(c.read(dailyReviewProvider), isNotNull);
  });

  test('groups still loading → review with alternative null; groups arrive → '
      'alternative set', () async {
    final c = container(
      now: _at(_today, 20),
      todayMeals: [_meal('m1', _today)],
      groups: const AsyncLoading(),
    );
    await settle(c);
    final loading = c.read(dailyReviewProvider)!;
    expect(loading.alternative, isNull);

    (c.read(ingredientSuggestionProvider.notifier) as _Suggestions).set(
      AsyncData([_group('m1', _today)]),
    );
    final arrived = c.read(dailyReviewProvider)!;
    expect(arrived.alternative?.replacement.id, 'chive');
    expect(arrived.alternativeLocked, isFalse);
  });

  test('dailyReviewAlternativeLockedProvider overridden true → '
      'alternativeLocked true, pick kept', () async {
    final c = container(
      now: _at(_today, 20),
      todayMeals: [_meal('m1', _today)],
      groups: AsyncData([_group('m1', _today)]),
      seamLocked: true,
    );
    await settle(c);
    final review = c.read(dailyReviewProvider)!;
    expect(review.alternativeLocked, isTrue);
    expect(review.alternative?.replacement.id, 'chive');
  });

  test('plusLockedProvider true → alternativeLocked true, pick kept, upsell '
      'route /plus', () async {
    final c = container(
      now: _at(_today, 20),
      todayMeals: [_meal('m1', _today)],
      groups: AsyncData([_group('m1', _today)]),
      plusLocked: true,
    );
    await settle(c);
    final review = c.read(dailyReviewProvider)!;
    expect(review.alternativeLocked, isTrue);
    expect(review.alternative?.replacement.id, 'chive');
    expect(c.read(dailyReviewUpsellRouteProvider), RoutePaths.plus);
    expect(c.read(dailyReviewExtrasProvider), isEmpty);
  });

  test('plusLockedProvider false → open, upsell route null', () async {
    final c = container(
      now: _at(_today, 20),
      todayMeals: [_meal('m1', _today)],
      groups: AsyncData([_group('m1', _today)]),
    );
    await settle(c);
    final review = c.read(dailyReviewProvider)!;
    expect(review.alternativeLocked, isFalse);
    expect(review.alternative, isNotNull);
    expect(c.read(dailyReviewUpsellRouteProvider), isNull);
  });

  test('during the Buddy onboarding → null', () async {
    final c = container(
      now: _at(_today, 20),
      todayMeals: [_meal('m1', _today)],
      onboarding: true,
    );
    await settle(c);
    expect(c.read(dailyReviewProvider), isNull);
  });

  test('signed out → null', () async {
    final c = container(
      now: _at(_today, 20),
      todayMeals: [_meal('m1', _today)],
    );
    user.set(c, null);
    await settle(c);
    expect(c.read(dailyReviewProvider), isNull);
  });

  test('entries holding another day → no review from them today', () async {
    final c = container(
      now: _at(_today, 20),
      entriesDay: _yesterday,
      todayMeals: [_meal('m1', _today)],
    );
    await settle(c);
    expect(c.read(dailyReviewProvider), isNull);
  });

  test('said flag is per user and day', () async {
    expect(await dailyReviewSaidOn('a', _today), isFalse);
    await recordDailyReviewSaid('a', _today);
    expect(await dailyReviewSaidOn('a', _today), isTrue);
    expect(await dailyReviewSaidOn('a', _yesterday), isFalse);
    expect(await dailyReviewSaidOn('b', _today), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('daily_review_said_a'), '2026-11-27');
  });
}
