// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/models/insight_source.dart';
import 'package:belly_buddy/models/journey_rewards.dart';
import 'package:belly_buddy/models/recipe.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/journey_provider.dart';
import 'package:belly_buddy/providers/journey_rewards_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/providers/recipe_collection_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/recipe_repository.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/logs.dart';
import '../helpers/riverpod_helpers.dart';

/// The signed-in user's id, switchable.
final _user = SwitchableUserId('u1');

/// The app's clock, pinned to another day than the test run's.
final _now = DateTime(2026, 11, 17, 14);

/// Two recipes that fit a Fruktose user, „Apfel-Reis" first in „Für dich".
final _a = testRecipe(
  id: 'a',
  title: 'Apfel-Reis',
  ingredients: [testLine('Reis')],
);
final _b = testRecipe(
  id: 'b',
  title: 'Bohnen-Topf',
  ingredients: [testLine('Kartoffel')],
);

RecipePick _pick(Recipe r) => RecipePick(id: r.id, title: r.title);

String _json(JourneyRewards r) => jsonEncode(r.toJson());

/// The insights' loads, the journey decision, the stored read and the
/// recipes all landed.
Future<void> _settle() => pumpEventQueue(times: 100);

/// An override for the rewards whose preferences open through [open].
Override _rewardsOpening(Future<SharedPreferences> Function() open) =>
    journeyRewardsProvider.overrideWith(
      () => JourneyRewardsNotifier(preferences: open),
    );

void main() {
  // The insights' new-day signal (an AppLifecycleListener) needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeEntryRepository entries;
  late FakeRecipeRepository recipes;

  /// [n] active days before today, no Bauchgefühl.
  InsightSource activeDays(int n) =>
      insightSourceFor(activeDays: n, gutFeelings: 0, now: _now);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    entries = FakeEntryRepository()..insightSource = activeDays(2);
    recipes = FakeRecipeRepository()..collection = [_a, _b];
  });

  ProviderContainer container({
    bool weeklyTips = false,
    List<Override> overrides = const [],
  }) => ProviderContainer.test(
    overrides: [
      _user.override,
      entryRepositoryProvider.overrideWithValue(entries),
      recipeRepositoryProvider.overrideWithValue(recipes),
      profileProviderSeededWith(
        testUserProfile(
          intolerances: ['Fruktose'],
          weeklyTipsEnabled: weeklyTips,
        ),
      ),
      buddyClockProvider.overrideWithValue(() => _now),
      ...overrides,
    ],
  );

  /// [c]'s rewards, listened to, once everything loaded.
  Future<JourneyRewards?> rewardsOf(ProviderContainer c) async {
    c.listen(journeyRewardsProvider, (_, _) {});
    await _settle();
    return c.read(journeyRewardsProvider);
  }

  /// What is stored for [userId]: its JSON, decoded.
  Future<Object?> storedJson([String userId = 'u1']) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      'journey_rewards_$userId',
    );
    return raw == null ? null : jsonDecode(raw);
  }

  Future<JourneyRewards?> stored([String userId = 'u1']) async =>
      JourneyRewards.fromJson(await storedJson(userId));

  group('journeyRewardsProvider', () {
    test('journey false (a user past day 7): null, nothing stored', () async {
      entries.insightSource = insightSourceFor(
        activeDays: 9,
        gutFeelings: 1,
        now: _now,
      );
      final c = container();

      expect(await rewardsOf(c), isNull);
      expect(c.read(journeyProvider), isFalse);
      expect(await storedJson(), isNull);
    });

    test('undecided (the insights still loading): null', () async {
      entries.holdInsightSource = true;
      final c = container();

      expect(await rewardsOf(c), isNull);
      expect(c.read(journeyProvider), isNull);
      expect(await storedJson(), isNull);
    });

    test('signed out: null', () async {
      final c = container();
      _user.set(c, null);

      expect(await rewardsOf(c), isNull);
    });

    test('a journey user: earned day 2 from 2 active days, stored as JSON '
        'under journey_rewards_<userId>', () async {
      final c = container();

      final rewards = await rewardsOf(c);

      expect(rewards, JourneyRewards(earnedDay: 2, picks: {1: _pick(_a)}));
      expect(await storedJson(), rewards!.toJson());
    });

    test('restart keeps the earned day and the picks: fewer active days '
        'never lower it, a new first recipe never replaces a pick', () async {
      entries.insightSource = activeDays(3);
      final first = await rewardsOf(container(weeklyTips: true));
      expect(first!.earnedDay, 3);
      expect(first.picks, {1: _pick(_a), 3: _pick(_b)});

      entries.insightSource = activeDays(1);
      recipes.collection = [testRecipe(id: 'n', title: 'Ahorn-Porridge'), _a];
      final second = await rewardsOf(container(weeklyTips: true));

      expect(second!.earnedDay, 3);
      expect(second.picks, first.picks);
      expect(await stored(), second);
    });

    test('picks once the ranking is checked: none while the rules fail, the '
        'day-1 pick stored once they are back', () async {
      recipes.rulesError = StateError('offline');
      final c = container();

      final unchecked = await rewardsOf(c);
      expect(unchecked!.earnedDay, 2);
      expect(unchecked.picks, isEmpty);
      expect((await stored())!.picks, isEmpty);

      recipes.rulesError = null;
      await c.read(recipeCollectionProvider.notifier).refresh();
      await _settle();

      expect(c.read(journeyRewardsProvider)!.picks, {1: _pick(_a)});
      expect((await stored())!.picks, {1: _pick(_a)});
    });

    test(
      'day 3: weekly off → offered, the recipe kept ready for „Nein"',
      () async {
        entries.insightSource = activeDays(3);

        final rewards = await rewardsOf(container());

        expect(rewards!.tipOffer, TipOffer.offered);
        expect(rewards.picks, {1: _pick(_a), 3: _pick(_b)});
        expect((await stored())!.tipOffer, TipOffer.offered);
      },
    );

    test('day 3: weekly on → skipped, the next recipe', () async {
      entries.insightSource = activeDays(3);

      final rewards = await rewardsOf(container(weeklyTips: true));

      expect(rewards!.tipOffer, TipOffer.skipped);
      expect(rewards.picks, {1: _pick(_a), 3: _pick(_b)});
      expect((await stored())!.tipOffer, TipOffer.skipped);
    });

    test('day 3 waits for the weekly tips to be known', () async {
      entries.insightSource = activeDays(3);
      final weekly = NotifierProvider<Switchable<bool?>, bool?>(
        () => Switchable(null),
      );
      final c = container(
        overrides: [
          weeklyTipsEnabledProvider.overrideWith((ref) => ref.watch(weekly)),
        ],
      );
      expect((await rewardsOf(c))!.tipOffer, isNull);

      c.read(weekly.notifier).set(false);
      await _settle();

      expect(c.read(journeyRewardsProvider)!.tipOffer, TipOffer.offered);
      expect((await stored())!.tipOffer, TipOffer.offered);
    });

    test('day 5 names the calm-day ingredients its recipe holds', () async {
      SharedPreferences.setMockInitialValues({
        'insight_journey_u1': true,
        'journey_rewards_u1': _json(
          const JourneyRewards(
            earnedDay: 4,
            picks: {
              1: RecipePick(id: 'p1', title: 'Früher 1'),
              3: RecipePick(id: 'p3', title: 'Früher 3'),
            },
            tipOffer: TipOffer.skipped,
          ),
        ),
      });
      final five = activeDays(5);
      entries.insightSource = InsightSource(
        meals: [
          InsightMeal(
            trackedAt: DateTime(2026, 11, 16, 12),
            ingredients: const ['Kartoffel'],
          ),
        ],
        gutFeelings: five.gutFeelings,
        activityTimes: five.activityTimes,
      );

      final rewards = await rewardsOf(container());

      expect(
        rewards!.picks[5],
        const RecipePick(id: 'b', title: 'Bohnen-Topf', matched: ['Kartoffel']),
      );
    });

    group('the ranking is followed only while a pick is missing', () {
      /// The collection reloaded (e.g. pulled to refresh elsewhere): whether
      /// the rewards still followed it, i.e. it was fetched again.
      Future<bool> follows(ProviderContainer c) async {
        final fetches = recipes.collectionFetches;
        c.invalidate(recipeCollectionProvider);
        await _settle();
        return recipes.collectionFetches > fetches;
      }

      test('day 2: day 3 and 5 still to pick → followed', () async {
        final c = container();
        expect((await rewardsOf(c))!.picks.keys, [1]);

        expect(await follows(c), isTrue);
      });

      test('all picks made → no longer followed', () async {
        recipes.collection = [
          _a,
          _b,
          testRecipe(
            id: 'c',
            title: 'Couscous',
            ingredients: [testLine('Karotte')],
          ),
        ];
        entries.insightSource = activeDays(5);
        final c = container();
        expect((await rewardsOf(c))!.picks.keys, unorderedEquals([1, 3, 5]));

        expect(await follows(c), isFalse);
      });

      test('all picks stored → the collection is not reloaded', () async {
        SharedPreferences.setMockInitialValues({
          'journey_rewards_u1': _json(
            JourneyRewards(
              earnedDay: 2,
              picks: {1: _pick(_a), 3: _pick(_b), 5: _pick(_a)},
            ),
          ),
        });
        final c = container();
        await rewardsOf(c);

        expect(await follows(c), isFalse);
      });
    });

    test('answerTipOffer „Nein": declined, stored, with day 3\'s recipe (the '
        'rule: answerOffer)', () async {
      entries.insightSource = activeDays(3);
      final c = container();
      expect((await rewardsOf(c))!.tipOffer, TipOffer.offered);

      await c
          .read(journeyRewardsProvider.notifier)
          .answerTipOffer(accepted: false);

      final rewards = c.read(journeyRewardsProvider)!;
      expect(rewards.tipOffer, TipOffer.declined);
      expect(rewards.picks, {1: _pick(_a), 3: _pick(_b)});
      expect(await stored(), rewards);
    });

    test('setFirstTip: both changes at once stored in order; failed stored, '
        'and firstTipFailedProvider true', () async {
      entries.insightSource = activeDays(3);
      final c = container();
      await rewardsOf(c);
      final notifier = c.read(journeyRewardsProvider.notifier);
      expect(c.read(firstTipFailedProvider), isFalse);

      await Future.wait([
        notifier.answerTipOffer(accepted: true),
        notifier.setFirstTip(FirstTipState.requested),
      ]);
      expect(
        await stored(),
        isA<JourneyRewards>()
            .having((r) => r.tipOffer, 'tipOffer', TipOffer.accepted)
            .having((r) => r.firstTip, 'firstTip', FirstTipState.requested),
      );

      await notifier.setFirstTip(FirstTipState.failed);

      expect((await stored())!.firstTip, FirstTipState.failed);
      expect(c.read(firstTipFailedProvider), isTrue);
    });

    for (final (name, value) in [
      ('not JSON', 'kein JSON {'),
      ('JSON of another shape', '{"earned": "zwei"}'),
      ('not a string', 42),
    ]) {
      test('unreadable stored JSON starts afresh, stored ($name)', () async {
        SharedPreferences.setMockInitialValues({'journey_rewards_u1': value});
        final logs = captureLogs();

        final rewards = await rewardsOf(container());

        expect(rewards, JourneyRewards(earnedDay: 2, picks: {1: _pick(_a)}));
        expect(await stored(), rewards);
        expect(logs, [
          startsWith(
            'JourneyRewards [WARN]: Stored journey rewards unreadable',
          ),
        ]);
      });
    }

    test('preferences that can\'t be opened: kept in memory only, the stored '
        'rewards never overwritten until a later read succeeds', () async {
      final kept = _json(JourneyRewards(earnedDay: 5, picks: {1: _pick(_b)}));
      SharedPreferences.setMockInitialValues({
        'insight_journey_u1': true,
        'journey_rewards_u1': kept,
      });
      final logs = captureLogs();
      var opens = 0;
      final c = container(
        overrides: [
          _rewardsOpening(() async {
            if (opens++ == 0) throw StateError('locked');
            return SharedPreferences.getInstance();
          }),
        ],
      );

      final rewards = await rewardsOf(c);
      await c
          .read(journeyRewardsProvider.notifier)
          .setFirstTip(FirstTipState.failed);

      expect(rewards, JourneyRewards(earnedDay: 2, picks: {1: _pick(_a)}));
      expect(c.read(firstTipFailedProvider), isTrue);
      expect(
        (await SharedPreferences.getInstance()).getString('journey_rewards_u1'),
        kept,
      );
      expect(
        logs.first,
        'JourneyRewards [ERROR]: Opening the journey rewards failed',
      );

      final restarted = await rewardsOf(container());
      expect(restarted!.earnedDay, 5);
      expect(restarted.picks[1], _pick(_b));
    });

    test('a switch while the read is pending: the previous user\'s rewards '
        'land nowhere', () async {
      final u1 = _json(const JourneyRewards(earnedDay: 5));
      SharedPreferences.setMockInitialValues({
        'insight_journey_u1': true,
        'insight_journey_u2': true,
        'journey_rewards_u1': u1,
        'journey_rewards_u2': _json(const JourneyRewards(earnedDay: 4)),
      });
      final held = Completer<void>();
      var opens = 0;
      final c = container(
        overrides: [
          _rewardsOpening(() async {
            if (opens++ == 0) await held.future;
            return SharedPreferences.getInstance();
          }),
        ],
      );
      final seen = <int?>[];
      c.listen(journeyRewardsProvider, (_, next) => seen.add(next?.earnedDay));
      await _settle();
      expect(opens, 1);
      expect(c.read(journeyRewardsProvider), isNull);

      _user.set(c, 'u2');
      await _settle();
      held.complete();
      await _settle();

      expect(c.read(journeyRewardsProvider)!.earnedDay, 4);
      expect(seen, isNot(contains(5)));
      expect((await stored('u2'))!.earnedDay, 4);
      expect(
        (await SharedPreferences.getInstance()).getString('journey_rewards_u1'),
        u1,
      );
    });

    test('another user reads their own key; the previous user\'s rewards '
        'never show for them', () async {
      SharedPreferences.setMockInitialValues({
        'insight_journey_u1': true,
        'insight_journey_u2': true,
        'journey_rewards_u1': _json(const JourneyRewards(earnedDay: 5)),
        'journey_rewards_u2': _json(const JourneyRewards(earnedDay: 4)),
      });
      final c = container();
      expect((await rewardsOf(c))!.earnedDay, 5);
      final seen = <int?>[];
      c.listen(journeyRewardsProvider, (_, next) => seen.add(next?.earnedDay));

      _user.set(c, 'u2');
      await _settle();

      expect(c.read(journeyRewardsProvider)!.earnedDay, 4);
      expect(seen, isNot(contains(5)));
      expect((await stored('u2'))!.earnedDay, 4);
      expect((await stored('u1'))!.earnedDay, 5);
    });
  });

  group('derived', () {
    test('a day-2 entry today: „Heute: Ein Wissen-Häppchen", day 2 '
        'announced, patterns not due, no failed tip', () async {
      entries.insightSource = InsightSource(
        meals: const [],
        gutFeelings: const [],
        activityTimes: [DateTime(2026, 11, 16, 9), DateTime(2026, 11, 17, 9)],
      );
      final c = container();
      await rewardsOf(c);

      expect(c.read(journeyRewardLineProvider), 'Heute: Ein Wissen-Häppchen');
      expect(c.read(journeyRewardAnnouncementProvider), 2);
      expect(c.read(patternsUnlockedDueProvider), isFalse);
      expect(c.read(firstTipFailedProvider), isFalse);
    });

    test('unlocked: no line, the patterns due', () async {
      SharedPreferences.setMockInitialValues({'insight_journey_u1': true});
      entries.insightSource = insightSourceFor(
        activeDays: 7,
        gutFeelings: 3,
        now: _now,
      );
      final c = container();

      final rewards = await rewardsOf(c);

      expect(rewards!.patternsFreed, isTrue);
      expect(c.read(journeyRewardLineProvider), isNull);
      expect(c.read(journeyRewardAnnouncementProvider), isNull);
      expect(c.read(patternsUnlockedDueProvider), isTrue);
    });

    test('without the journey: no line, nothing announced or due', () async {
      entries.insightSource = insightSourceFor(
        activeDays: 9,
        gutFeelings: 1,
        now: _now,
      );
      final c = container();
      await rewardsOf(c);

      expect(c.read(journeyRewardLineProvider), isNull);
      expect(c.read(journeyRewardAnnouncementProvider), isNull);
      expect(c.read(patternsUnlockedDueProvider), isFalse);
      expect(c.read(firstTipFailedProvider), isFalse);
    });
  });
}
