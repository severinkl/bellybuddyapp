// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/config/constants.dart';

import 'package:belly_buddy/models/pattern_stats.dart';
import 'package:belly_buddy/models/tolerance_test.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/buddy_offers_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/daily_review_provider.dart';
import 'package:belly_buddy/providers/notification_provider.dart';
import 'package:belly_buddy/providers/pattern_stats_provider.dart';
import 'package:belly_buddy/providers/plus_provider.dart';
import 'package:belly_buddy/providers/tolerance_test_offer_provider.dart';
import 'package:belly_buddy/providers/tolerance_test_provider.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/services/pattern_stats_service.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/riverpod_helpers.dart';

const _zwiebel = TestSubject('ingredient', 'zwiebel', 'Zwiebel');
const _fruktane = TestSubject('group', 'fructans', 'Fruktane');

ToleranceTestView _test({
  String id = 't1',
  String status = 'active',
  TestPhase phase = TestPhase.leaveOut,
  int dayIndex = 2,
  TestResult? result,
}) => ToleranceTestView(
  id: id,
  subject: _zwiebel,
  origin: 'proposed',
  status: status,
  phase: phase,
  startsOn: DateTime(2026, 12, 1),
  leaveOutDays: 5,
  reintroDays: 3,
  dayIndex: dayIndex,
  days: const [],
  result: result,
);

const _result = TestResult(
  goodWithout: 4,
  countedWithout: 5,
  goodWith: 1,
  countedWith: 3,
  outcome: TestOutcome.worse,
);

PatternStats _stats({
  TestSubject? proposal = _zwiebel,
  ToleranceTestView? test,
  bool restrictive = false,
}) => PatternStats(
  windowDays: 90,
  ratedDays: 41,
  hardDays: 9,
  ready: true,
  proposal: proposal,
  test: test,
  restrictive: restrictive,
);

/// Pattern stats that hold [value] from the start; [set] replaces it.
class _Stats extends PatternStatsNotifier {
  _Stats(this._value);
  final AsyncValue<PatternStats?> _value;

  @override
  Future<PatternStats?> build() async {
    final v = _value;
    if (v is AsyncError<PatternStats?>) {
      Error.throwWithStackTrace(v.error, v.stackTrace);
    }
    // Loading stays loading.
    if (v.isLoading) return Completer<PatternStats?>().future;
    return v.value;
  }

  void set(AsyncValue<PatternStats?> v) => state = v;
}

void main() {
  late _Stats stats;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer make({
    AsyncValue<PatternStats?>? value,
    bool plusLocked = false,
    bool unlocked = true,
    AsyncValue<bool> askDue = const AsyncData(false),
    BuddyStatus? buddy,
    List<Override> extra = const [],
  }) {
    stats = _Stats(value ?? AsyncData(_stats()));
    final c = ProviderContainer.test(
      overrides: [
        patternStatsProvider.overrideWith(() => stats),
        plusLockedProvider.overrideWithValue(plusLocked),
        insightsProviderSeededWith(
          unlocked
              ? lockedInsights(activeDays: 7, gutFeelings: 3)
              : lockedInsights(),
        ),
        reminderAskDueProvider.overrideWithValue(askDue),
        buddyProvider.overrideWith(() => FakeBuddyNotifier(() => buddy)),
        currentUserIdProvider.overrideWithValue(testUserId),
        ...extra,
      ],
    );
    c.listen(toleranceTestOfferDueProvider, (_, _) {});
    c.listen(buddyOffersProvider, (_, _) {});
    return c;
  }

  Future<void> settle(ProviderContainer c) async {
    for (var i = 0; i < 10; i++) {
      await pumpEventQueue();
    }
  }

  group('toleranceTestOfferDueProvider', () {
    test('offer due only with a proposal, unlocked insights and no active '
        'test', () async {
      Future<TestSubject?> due({
        PatternStats? s,
        bool unlocked = true,
        bool plusLocked = false,
      }) async {
        final c = make(
          value: AsyncData(s ?? _stats()),
          unlocked: unlocked,
          plusLocked: plusLocked,
        );
        await settle(c);
        return c.read(toleranceTestOfferDueProvider);
      }

      expect(await due(), _zwiebel);
      expect(await due(s: _stats(proposal: null)), isNull);
      expect(await due(unlocked: false), isNull);
      expect(await due(plusLocked: true), isNull);
      expect(await due(s: _stats(test: _test())), isNull);
      expect(await due(s: _stats(restrictive: true)), isNull);
      // A completed test (its result shown) doesn't hold an offer back.
      expect(
        await due(
          s: _stats(
            test: _test(
              status: 'completed',
              phase: TestPhase.done,
              result: _result,
            ),
          ),
        ),
        _zwiebel,
      );
    });

    test('no offer before the stats loaded or while they are locked', () async {
      final c = make(value: const AsyncLoading());
      expect(c.read(toleranceTestOfferDueProvider), isNull);

      stats.set(
        const AsyncError(PatternStatsLockedException(), StackTrace.empty),
      );
      expect(c.read(toleranceTestOfferDueProvider), isNull);
    });

    test('no offer while stats are an error', () async {
      final c = make();
      await settle(c);
      expect(c.read(toleranceTestOfferDueProvider), _zwiebel);

      // An error that keeps the previous value.
      stats.set(
        const AsyncError<PatternStats?>(
          'offline',
          StackTrace.empty,
        ).copyWithPrevious(AsyncData(_stats())),
      );
      expect(c.read(toleranceTestOfferDueProvider), isNull);
    });

    test('no offer while the reminders ask is due', () async {
      for (final ask in [const AsyncData(true), const AsyncLoading<bool>()]) {
        final c = make(askDue: ask);
        await settle(c);
        expect(c.read(toleranceTestOfferDueProvider), isNull, reason: '$ask');
      }
      // A failed check counts as not due.
      final c = make(askDue: const AsyncError('x', StackTrace.empty));
      await settle(c);
      expect(c.read(toleranceTestOfferDueProvider), _zwiebel);
    });
  });

  group('buddyOffersProvider: the test cues', () {
    test('offer suffix is kind_key; a declined subject is not offered '
        'again', () async {
      final c = make(
        value: AsyncData(_stats(proposal: _fruktane)),
        buddy: buddyStatus(),
      );
      await settle(c);
      expect(
        c.read(buddyOffersProvider)[BuddyAnnouncement.testOffer],
        'group_fructans',
      );

      // Shown once (either answer marks it so), its flag holds it back.
      final buddy = c.read(buddyProvider.notifier);
      await c.read(buddyProvider.future);
      Future<List<BuddyAnnouncement>> offer() async {
        await buddy.offerAnnouncement(
          BuddyAnnouncement.testOffer,
          suffix: c.read(buddyOffersProvider)[BuddyAnnouncement.testOffer]!,
        );
        return c.read(buddyProvider).value!.announcements;
      }

      expect(await offer(), [BuddyAnnouncement.testOffer]);
      await buddy.markAnnouncementsShown(const [BuddyAnnouncement.testOffer]);
      expect(await offer(), isEmpty);
      // Another subject is offered.
      stats.set(AsyncData(_stats(proposal: _zwiebel)));
      expect(await offer(), [BuddyAnnouncement.testOffer]);
    });

    test('reintro on the first reintroduction day, done while the result is '
        'shown; never while Plus is locked', () async {
      var c = make(
        value: AsyncData(
          _stats(test: _test(phase: TestPhase.reintro, dayIndex: 6)),
        ),
      );
      await settle(c);
      expect(c.read(buddyOffersProvider), {
        BuddyAnnouncement.testReintro: 't1_reintro',
      });

      c = make(
        value: AsyncData(
          _stats(test: _test(phase: TestPhase.reintro, dayIndex: 7)),
        ),
      );
      await settle(c);
      expect(c.read(buddyOffersProvider), isEmpty);

      final done = _stats(
        test: _test(
          status: 'completed',
          phase: TestPhase.done,
          result: _result,
        ),
      );
      c = make(value: AsyncData(done));
      await settle(c);
      expect(c.read(buddyOffersProvider), {
        BuddyAnnouncement.testDone: 't1_done',
        BuddyAnnouncement.testOffer: 'ingredient_zwiebel',
      });

      c = make(value: AsyncData(done), plusLocked: true);
      await settle(c);
      expect(c.read(buddyOffersProvider), isEmpty);
    });
  });

  group('offerStillAppliesProvider: the test cues', () {
    BuddyStatus pending(BuddyAnnouncement kind, String suffix) => buddyStatus(
      announcements: [kind],
      announcementKeys: {
        kind:
            '${AppConstants.keyBuddyAnnouncedPrefix}${testUserId}_'
            '${kind.name}_$suffix',
      },
    );

    Future<bool> applies(
      BuddyAnnouncement kind,
      String suffix, {
      AsyncValue<PatternStats?>? value,
      bool plusLocked = false,
    }) async {
      final c = make(
        value: value,
        plusLocked: plusLocked,
        buddy: pending(kind, suffix),
      );
      await c.read(buddyProvider.future);
      await settle(c);
      return c.read(offerStillAppliesProvider(kind));
    }

    test('testOffer: while its subject is still the one; loading keeps it; '
        'locked or another subject withdraws it', () async {
      const offer = BuddyAnnouncement.testOffer;
      expect(await applies(offer, 'ingredient_zwiebel'), isTrue);
      expect(await applies(offer, 'group_fructans'), isFalse);
      expect(
        await applies(
          offer,
          'ingredient_zwiebel',
          value: AsyncData(_stats(test: _test())),
        ),
        isFalse,
      );
      expect(
        await applies(offer, 'ingredient_zwiebel', plusLocked: true),
        isFalse,
      );
      expect(
        await applies(offer, 'ingredient_zwiebel', value: const AsyncLoading()),
        isTrue,
      );
    });

    test('testReintro / testDone: while their condition holds for their '
        'test', () async {
      final reintro = AsyncData<PatternStats?>(
        _stats(test: _test(phase: TestPhase.reintro, dayIndex: 6)),
      );
      expect(
        await applies(
          BuddyAnnouncement.testReintro,
          't1_reintro',
          value: reintro,
        ),
        isTrue,
      );
      expect(
        await applies(
          BuddyAnnouncement.testReintro,
          't0_reintro',
          value: reintro,
        ),
        isFalse,
      );
      expect(
        await applies(
          BuddyAnnouncement.testDone,
          't1_done',
          value: AsyncData(_stats(test: _test())),
        ),
        isFalse,
      );
      expect(
        await applies(
          BuddyAnnouncement.testDone,
          't1_done',
          value: AsyncData(
            _stats(
              test: _test(
                status: 'completed',
                phase: TestPhase.done,
                result: _result,
              ),
            ),
          ),
        ),
        isTrue,
      );
    });
  });

  group('dailyReviewExtrasProvider', () {
    List<String> lines(PatternStats s, {bool plusLocked = false}) {
      final c = ProviderContainer.test(
        overrides: [
          patternStatsProvider.overrideWith(() => _Stats(AsyncData(s))),
          plusLockedProvider.overrideWithValue(plusLocked),
        ],
      );
      c.listen(patternStatsProvider, (_, _) {});
      return [for (final l in c.read(dailyReviewExtrasProvider)) l.text];
    }

    test(
      'one line while a test runs and Plus is open, to the test page',
      () async {
        final c = ProviderContainer.test(
          overrides: [
            patternStatsProvider.overrideWith(
              () => _Stats(AsyncData(_stats(test: _test(dayIndex: 2)))),
            ),
            plusLockedProvider.overrideWithValue(false),
          ],
        );
        c.listen(patternStatsProvider, (_, _) {});
        await c.read(patternStatsProvider.future);
        final extras = c.read(dailyReviewExtrasProvider);
        expect(extras, hasLength(1));
        expect(
          extras.single.text,
          'Verträglichkeits-Test: heute ohne Zwiebel (Tag 2 von 8)',
        );
        expect(extras.single.route, RoutePaths.toleranceTest);
      },
    );

    test('reintro reads „wieder mit"; none before the start, once over, '
        'or while Plus is locked', () async {
      Future<List<String>> after(PatternStats s, {bool locked = false}) async {
        final c = ProviderContainer.test(
          overrides: [
            patternStatsProvider.overrideWith(() => _Stats(AsyncData(s))),
            plusLockedProvider.overrideWithValue(locked),
          ],
        );
        c.listen(patternStatsProvider, (_, _) {});
        await c.read(patternStatsProvider.future);
        return [for (final l in c.read(dailyReviewExtrasProvider)) l.text];
      }

      expect(
        await after(_stats(test: _test(phase: TestPhase.reintro, dayIndex: 7))),
        ['Verträglichkeits-Test: heute wieder mit Zwiebel (Tag 7 von 8)'],
      );
      expect(await after(_stats(test: _test(dayIndex: 0))), isEmpty);
      expect(
        await after(
          _stats(
            test: _test(phase: TestPhase.done, dayIndex: 9, result: _result),
          ),
        ),
        isEmpty,
      );
      expect(await after(_stats(test: _test()), locked: true), isEmpty);
      expect(lines(_stats(), plusLocked: true), isEmpty);
    });
  });

  group('ToleranceTestReminders', () {
    test('schedules the reintro and result days only with the permission; '
        'cancel cancels', () async {
      final os = FakeNotificationRepository();
      final reminders = ToleranceTestReminders(os);
      final t = _test();

      expect(await reminders.schedule(t), isTrue);
      expect(
        os.testReminders.single.reintroBody,
        'Ab heute darf Zwiebel wieder auf den Teller – ich schau, wie\'s '
        'deinem Bauch damit geht.',
      );
      expect(os.testReminders.single.reintroDay, DateTime(2026, 12, 6));
      expect(os.testReminders.single.resultDay, DateTime(2026, 12, 9));

      os.permission = NotificationPermission.notDetermined;
      expect(await reminders.schedule(t), isFalse);
      os.permission = NotificationPermission.denied;
      await reminders.schedule(t);
      expect(os.testReminders, hasLength(1));
      expect(os.requests, 0, reason: 'no new ask');

      await reminders.cancel();
      expect(os.testReminderCancels, 1);
    });

    test('a group\'s reintro notification reads as its foods', () async {
      final os = FakeNotificationRepository();
      final group = ToleranceTestView(
        id: 'g1',
        subject: _fruktane,
        origin: 'proposed',
        status: 'active',
        phase: TestPhase.leaveOut,
        startsOn: DateTime(2026, 12, 1),
        leaveOutDays: 5,
        reintroDays: 3,
        dayIndex: 1,
        days: const [],
      );

      await ToleranceTestReminders(os).schedule(group);

      expect(
        os.testReminders.single.reintroBody,
        'Ab heute dürfen Lebensmittel mit Fruktanen wieder auf den Teller – '
        'ich schau, wie\'s deinem Bauch damit geht.',
      );
    });
  });
}
