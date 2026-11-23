import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/providers/buddy_offers_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/repositories/recommendation_repository.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';

/// The signed-in user's id, switchable.
class _UserId extends Notifier<String?> {
  @override
  String? build() => testUserId;

  void set(String? id) => state = id;
}

final _userIdProvider = NotifierProvider<_UserId, String?>(_UserId.new);

void main() {
  // The foreground signal (an AppLifecycleListener) needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 11, 23, 14);
  late FakeEntryRepository entryRepo;
  late FakeRecommendationRepository tips;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Unlocked: 7 active days, 3 gut-feeling entries.
    entryRepo = FakeEntryRepository()
      ..insightSource = insightSourceFor(
        activeDays: 7,
        gutFeelings: 3,
        now: now,
      );
    // Nothing new: the default set was seen.
    tips = FakeRecommendationRepository();
  });

  /// A container whose weekly tips are [weeklyTips] (null: profile not
  /// known), with the offers listened to and the insights and tips loaded.
  Future<ProviderContainer> loaded({bool? weeklyTips = false}) async {
    final c = ProviderContainer.test(
      overrides: [
        entryRepositoryProvider.overrideWithValue(entryRepo),
        recommendationRepositoryProvider.overrideWithValue(tips),
        currentUserIdProvider.overrideWith((ref) => ref.watch(_userIdProvider)),
        buddyClockProvider.overrideWithValue(() => now),
        weeklyTipsEnabledProvider.overrideWithValue(weeklyTips),
      ],
    );
    c.listen(buddyOffersProvider, (_, _) {});
    await c.read(insightsProvider.future);
    await c.read(recommendationProvider.notifier).fetchRecommendations();
    return c;
  }

  group('buddyOffersProvider', () {
    test('an unseen set: tipsArrived with its id', () async {
      tips.sets = [testRecommendation(id: 'rec-1')];
      final c = await loaded(weeklyTips: true);

      expect(c.read(buddyOffersProvider), {
        BuddyAnnouncement.tipsArrived: 'rec-1',
      });
    });

    test('all seen: nothing', () async {
      final c = await loaded(weeklyTips: true);

      expect(c.read(buddyOffersProvider), isEmpty);
    });

    test('unlocked and weekly tips off: the weekly-tips offer', () async {
      final c = await loaded();

      expect(c.read(weeklyTipsOfferDueProvider), isTrue);
      expect(
        c.read(buddyOffersProvider),
        containsPair(BuddyAnnouncement.weeklyTipsOffer, 'once'),
      );
      expect(weeklyTipsOfferSuffix, 'once');
    });

    test('unlocked and weekly tips on: no offer', () async {
      final c = await loaded(weeklyTips: true);

      expect(c.read(weeklyTipsOfferDueProvider), isFalse);
      expect(
        c.read(buddyOffersProvider),
        isNot(contains(BuddyAnnouncement.weeklyTipsOffer)),
      );
    });

    test('locked: no offer', () async {
      entryRepo.insightSource = insightSourceFor(
        activeDays: 7,
        gutFeelings: 2,
        now: now,
      );
      final c = await loaded();

      expect(c.read(insightsProvider).value!.unlocked, isFalse);
      expect(c.read(weeklyTipsOfferDueProvider), isFalse);
      expect(c.read(buddyOffersProvider), isEmpty);
    });

    test('profile unknown: no offer', () async {
      final c = await loaded(weeklyTips: null);

      expect(c.read(weeklyTipsOfferDueProvider), isFalse);
      expect(c.read(buddyOffersProvider), isEmpty);
    });

    test('insights reloading for another user: no offer', () async {
      final c = await loaded();
      expect(c.read(weeklyTipsOfferDueProvider), isTrue);

      // The next user's insights load; the state keeps the previous
      // user's unlocked value meanwhile.
      entryRepo.holdInsightSource = true;
      c.read(_userIdProvider.notifier).set('u2');
      final insights = c.read(insightsProvider);
      expect(insights, isA<AsyncLoading<Object?>>());
      expect(insights.value!.unlocked, isTrue);

      expect(c.read(weeklyTipsOfferDueProvider), isFalse);
      expect(c.read(buddyOffersProvider), isEmpty);
    });
  });
}
