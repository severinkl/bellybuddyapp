import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/models/knowledge_article.dart';
import 'package:belly_buddy/models/plus_status.dart';
import 'package:belly_buddy/models/progress.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/for_you_provider.dart';
import 'package:belly_buddy/providers/insights_provider.dart';
import 'package:belly_buddy/providers/knowledge_opened_provider.dart';
import 'package:belly_buddy/providers/knowledge_provider.dart';
import 'package:belly_buddy/providers/plus_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/providers/progress_provider.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/repositories/knowledge_repository.dart';
import 'package:belly_buddy/services/purchases/purchases_gateway.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/purchases_fakes.dart';
import '../helpers/riverpod_helpers.dart';

final _laktose = KnowledgeArticle(
  title: 'Laktose im Alltag',
  link: Uri.parse('https://www.myfodmap.at/laktose'),
  category: 'Gesund verdauen',
  publishedAt: DateTime.utc(2026, 11, 22, 8),
);

final _verstopfung = KnowledgeArticle(
  title: 'Reizdarm Typ: Verstopfung',
  link: Uri.parse('https://www.myfodmap.at/verstopfung'),
  category: 'Gesund verdauen',
  publishedAt: DateTime.utc(2026, 11, 21, 8),
);

final _zwiebel = KnowledgeArticle(
  title: 'Zwiebel und Co.',
  link: Uri.parse('https://www.myfodmap.at/zwiebel'),
  category: 'Gesund verdauen',
  publishedAt: DateTime.utc(2026, 11, 20, 8),
);

/// Unlocked Muster whose one „Fällt mir auf" item is Zwiebel.
const _zwiebelInsights = Insights(
  progress: InsightProgress(activeDays: 30, gutFeelingEntries: 30),
  calendar: [],
  goodDays: DayColumn(days: 0),
  hardDays: DayColumn(days: 0),
  noticed: [
    Noticed(name: 'Zwiebel', hard: 9, hardDays: 10, good: 1, goodDays: 10),
  ],
  pick: NothingYetPick(),
  journey: [],
);

/// A week with three Klo entries, two of them hard.
const _hardWeek = RecentSignals(klo: 3, kloHard: 2, kloLoose: 0);

Progress _progress(RecentSignals recent) => Progress(
  weeks: const [],
  good: 0,
  medium: 0,
  hard: 0,
  activeDays: 0,
  elapsedDays: 0,
  longestStreak: 0,
  recent: recent,
);

/// Serves [value] once [gate] (when set at build time) completes; follows
/// the signed-in user like the real one.
class _GatedProgress extends ProgressNotifier {
  _GatedProgress(this.value);

  Progress? value;
  Completer<void>? gate;

  @override
  Future<Progress?> build() async {
    ref.watch(currentUserIdProvider);
    await gate?.future;
    return value;
  }
}

/// Serves [value] once [gate] (when set at build time) completes; follows
/// the signed-in user like the real one.
class _GatedInsights extends InsightsNotifier {
  _GatedInsights(this.value);

  Insights value;
  Completer<void>? gate;

  @override
  Future<Insights> build() async {
    ref.watch(currentUserIdProvider);
    await gate?.future;
    return value;
  }
}

/// The profile, set by the test; starts loading.
class _ProfileLater extends ProfileNotifier {
  @override
  AsyncValue<UserProfile?> build() => const AsyncValue.loading();

  void load(UserProfile? profile) => state = AsyncValue.data(profile);
}

/// A profile repository whose reads wait for [hold] and fail with [error]
/// when set.
class _HeldProfileRepository extends FakeProfileRepository {
  Completer<void>? hold;
  Object? error;

  @override
  Future<UserProfile?> getProfile(String userId) async {
    await hold?.future;
    if (error case final e?) throw e;
    return super.getProfile(userId);
  }
}

void main() {
  late FakeKnowledgeRepository repo;
  late _GatedProgress progress;
  late SwitchableUserId user;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = FakeKnowledgeRepository(
      articles: [_laktose, _verstopfung, ...testKnowledgeArticles()],
    );
    progress = _GatedProgress(null);
    user = SwitchableUserId();
  });

  ProviderContainer container({ProfileNotifier Function()? profile}) {
    final c = ProviderContainer.test(
      overrides: [
        user.override,
        knowledgeRepositoryProvider.overrideWithValue(repo),
        progressProvider.overrideWith(() => progress),
        insightsProviderSeededWith(lockedInsights()),
        profile == null
            ? profileProviderSeededWith(
                testUserProfile(intolerances: const ['Laktose']),
              )
            : profileProvider.overrideWith(profile),
      ],
    );
    c.listen(forYouProvider, (_, _) {});
    return c;
  }

  Future<void> settle(ProviderContainer c) async {
    await c.read(knowledgeFeedProvider.future);
    await c.read(knowledgeOpenedProvider.future);
    await c.read(progressProvider.future).catchError((_) => null);
    await pumpEventQueue();
  }

  List<Uri> links(ProviderContainer c) => [
    for (final p in c.read(forYouProvider)) p.article.link,
  ];

  test('empty while the feed or the profile is loading', () async {
    final hold = Completer<void>();
    repo.fetchHold = hold;
    final profile = _ProfileLater();
    final c = container(profile: () => profile);

    expect(c.read(forYouProvider), isEmpty);

    hold.complete();
    await settle(c);
    expect(
      c.read(forYouProvider),
      isEmpty,
      reason: 'the feed is there, the profile still loading',
    );

    profile.load(testUserProfile(intolerances: const ['Laktose']));
    await pumpEventQueue();
    expect(links(c), [_laktose.link]);
    expect(
      c.read(forYouProvider).single.reason,
      'Weil du Laktose angegeben hast',
    );
  });

  test(
    'uses recent signals once progress has a value; works without it',
    () async {
      final gate = Completer<void>();
      progress
        ..value = _progress(_hardWeek)
        ..gate = gate;
      final c = container();
      await c.read(knowledgeFeedProvider.future);
      await c.read(knowledgeOpenedProvider.future);
      await pumpEventQueue();

      expect(links(c), [_laktose.link], reason: 'progress still loading');

      gate.complete();
      await settle(c);
      expect(links(c), [_verstopfung.link, _laktose.link]);
      expect(
        c.read(forYouProvider).first.reason,
        'Weil es beim Klo diese Woche öfter hart war',
      );

      // Another user: the previous user's week never shapes the picks while
      // the new one's loads.
      progress
        ..value = _progress(_hardWeek)
        ..gate = Completer<void>();
      user.set(c, 'other-user');
      await pumpEventQueue();
      expect(c.read(progressProvider).isReloading, isTrue);
      expect(links(c), isNot(contains(_verstopfung.link)));
    },
  );

  test('an opened article leaves the picks', () async {
    final c = container();
    await settle(c);
    expect(links(c), [_laktose.link]);

    await c.read(knowledgeOpenedProvider.notifier).markOpened(_laktose.link);
    expect(c.read(forYouProvider), isEmpty);
  });

  test(
    "another user's Muster items never shape the picks while theirs load",
    () async {
      repo = FakeKnowledgeRepository(articles: [_zwiebel]);
      final insights = _GatedInsights(_zwiebelInsights);
      final c = ProviderContainer.test(
        overrides: [
          user.override,
          knowledgeRepositoryProvider.overrideWithValue(repo),
          progressProvider.overrideWith(() => progress),
          insightsProvider.overrideWith(() => insights),
          profileProviderSeededWith(testUserProfile(intolerances: const [])),
        ],
      );
      c.listen(forYouProvider, (_, _) {});
      await c.read(knowledgeFeedProvider.future);
      await c.read(knowledgeOpenedProvider.future);
      await c.read(insightsProvider.future);
      await pumpEventQueue();
      expect(links(c), [
        _zwiebel.link,
      ], reason: 'user A: the Muster item picks');

      insights.gate = Completer<void>();
      user.set(c, 'other-user');
      await pumpEventQueue();
      expect(c.read(insightsProvider).isReloading, isTrue);
      expect(links(c), isEmpty, reason: "user B's insights are still loading");
    },
  );

  test(
    'a profile reload keeps the picks; sign-out and an error drop them',
    () async {
      final profiles = _HeldProfileRepository()
        ..seedProfile(testUserProfile(intolerances: const ['Laktose']));
      final c = ProviderContainer.test(
        overrides: [
          user.override,
          knowledgeRepositoryProvider.overrideWithValue(repo),
          progressProvider.overrideWith(() => progress),
          insightsProviderSeededWith(lockedInsights()),
          profileRepositoryProvider.overrideWithValue(profiles),
        ],
      );
      c.listen(forYouProvider, (_, _) {});
      final notifier = c.read(profileProvider.notifier);
      await notifier.fetchProfile();
      await settle(c);
      expect(links(c), [_laktose.link]);

      // App resume / pull to refresh: the profile reloads.
      profiles.hold = Completer<void>();
      final reload = notifier.fetchProfile();
      await pumpEventQueue();
      expect(c.read(profileProvider).isLoading, isTrue);
      expect(links(c), [_laktose.link], reason: 'same user, reloading');
      profiles.hold!.complete();
      await reload;
      await pumpEventQueue();
      expect(links(c), [_laktose.link]);

      // A failed reload: no value, no picks.
      profiles.error = Exception('offline');
      await notifier.fetchProfile();
      await pumpEventQueue();
      expect(c.read(forYouProvider), isEmpty);
      profiles.error = null;
      await notifier.fetchProfile();
      await pumpEventQueue();
      expect(links(c), [_laktose.link]);

      // Sign-out, then another user's profile loading: never the old picks.
      notifier.reset();
      user.set(c, 'other-user');
      profiles.hold = Completer<void>();
      final other = notifier.fetchProfile();
      await pumpEventQueue();
      expect(c.read(profileProvider).isLoading, isTrue);
      expect(c.read(forYouProvider), isEmpty);
      profiles.hold!.complete();
      await other;
    },
  );
  group('Belly Buddy Plus: the Muster shape the picks only while open', () {
    /// The switch [paywallOn], a signed-in user with an SDK key and Plus in
    /// [state]; Zwiebel is the user's Muster item.
    Future<ProviderContainer> plusContainer({
      required bool paywallOn,
      required PlusState state,
    }) async {
      repo = FakeKnowledgeRepository(articles: [_zwiebel]);
      final c = ProviderContainer.test(
        overrides: [
          user.override,
          knowledgeRepositoryProvider.overrideWithValue(repo),
          progressProvider.overrideWith(() => progress),
          insightsProviderSeededWith(_zwiebelInsights),
          profileProviderSeededWith(testUserProfile(intolerances: const [])),
          paywallEnabledProvider.overrideWithValue(paywallOn),
          purchasesGatewayProvider.overrideWithValue(FakePurchasesGateway()),
          plusProvider.overrideWith(
            () => FakePlusNotifier.status(PlusStatus(state: state)),
          ),
        ],
      );
      c.listen(forYouProvider, (_, _) {});
      await settle(c);
      await c.read(insightsProvider.future);
      await pumpEventQueue();
      return c;
    }

    test('locked: no Muster pick, no Muster reason', () async {
      final c = await plusContainer(paywallOn: true, state: PlusState.none);
      expect(c.read(plusLockedProvider), isTrue);
      expect(c.read(forYouProvider), isEmpty);
    });

    test('lapsed counts as locked', () async {
      final c = await plusContainer(paywallOn: true, state: PlusState.lapsed);
      expect(c.read(forYouProvider), isEmpty);
    });

    test('unlocked (trial): the Muster item picks', () async {
      final c = await plusContainer(paywallOn: true, state: PlusState.trial);
      expect(c.read(plusLockedProvider), isFalse);
      expect(links(c), [_zwiebel.link]);
      expect(
        c.read(forYouProvider).single.reason,
        'Weil Zwiebel bei dir auffällt',
      );
    });

    test('switch off: the Muster item picks, as before Plus', () async {
      final c = await plusContainer(paywallOn: false, state: PlusState.none);
      expect(c.read(plusLockedProvider), isFalse);
      expect(links(c), [_zwiebel.link]);
    });

    test('status unknown (loading): fails open', () async {
      repo = FakeKnowledgeRepository(articles: [_zwiebel]);
      final hold = Completer<PlusStatus>();
      final c = ProviderContainer.test(
        overrides: [
          user.override,
          knowledgeRepositoryProvider.overrideWithValue(repo),
          progressProvider.overrideWith(() => progress),
          insightsProviderSeededWith(_zwiebelInsights),
          profileProviderSeededWith(testUserProfile(intolerances: const [])),
          paywallEnabledProvider.overrideWithValue(true),
          purchasesGatewayProvider.overrideWithValue(FakePurchasesGateway()),
          plusProvider.overrideWith(() => FakePlusNotifier(() => hold.future)),
        ],
      );
      c.listen(forYouProvider, (_, _) {});
      await settle(c);
      await c.read(insightsProvider.future);
      await pumpEventQueue();
      expect(links(c), [_zwiebel.link]);

      hold.complete(PlusStatus.none);
      await pumpEventQueue();
      expect(c.read(forYouProvider), isEmpty, reason: 'now known: locked');
    });
  });
}
