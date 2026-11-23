import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/providers/buddy_events_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/insight_progress_provider.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';

import '../helpers/fakes.dart';
import '../helpers/riverpod_helpers.dart';

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('InsightProgress', () {
    test('daysLeft/gutFeelingsLeft/unlocked', () {
      const early = InsightProgress(activeDays: 2, gutFeelingEntries: 1);
      expect(early.daysLeft, 5);
      expect(early.gutFeelingsLeft, 2);
      expect(early.unlocked, isFalse);

      const done = InsightProgress(activeDays: 7, gutFeelingEntries: 3);
      expect(done.daysLeft, 0);
      expect(done.gutFeelingsLeft, 0);
      expect(done.unlocked, isTrue);

      // Beyond the goal: nothing left, never negative.
      const more = InsightProgress(activeDays: 12, gutFeelingEntries: 9);
      expect(more.daysLeft, 0);
      expect(more.gutFeelingsLeft, 0);
      expect(more.unlocked, isTrue);

      // One of the two still missing: locked.
      expect(
        const InsightProgress(activeDays: 9, gutFeelingEntries: 2).unlocked,
        isFalse,
      );
      expect(
        const InsightProgress(activeDays: 6, gutFeelingEntries: 3).unlocked,
        isFalse,
      );
    });
  });

  group('insightProgressProvider', () {
    final now = DateTime(2026, 11, 23, 14);
    final event = BuddyLogEvent(
      EntryKind.meal,
      LogSentiment.good,
      at: now,
      trackedAt: now,
    );
    late FakeEntryRepository entryRepo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      entryRepo = FakeEntryRepository()
        ..insightProgress = const InsightProgress(
          activeDays: 2,
          gutFeelingEntries: 1,
        );
    });

    ProviderContainer makeContainer({String? userId = 'u1'}) => createContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(entryRepo),
        buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
        currentUserIdProvider.overrideWithValue(userId),
        buddyTodayProvider.overrideWithValue(() => now),
      ],
    );

    test('loads the progress as of now', () async {
      final c = makeContainer();

      final progress = await c.read(insightProgressProvider.future);

      expect(
        progress,
        const InsightProgress(activeDays: 2, gutFeelingEntries: 1),
      );
      expect(entryRepo.insightProgressFetches, [now]);
    });

    test('provider refetches after a log event', () async {
      final c = makeContainer();
      await c.read(insightProgressProvider.future);
      entryRepo.insightProgress = const InsightProgress(
        activeDays: 3,
        gutFeelingEntries: 2,
      );

      c.read(buddyEventsProvider.notifier).emit(event);
      await settle();

      expect(entryRepo.insightProgressFetches, hasLength(2));
      expect(
        c.read(insightProgressProvider).value,
        const InsightProgress(activeDays: 3, gutFeelingEntries: 2),
      );
    });

    test('refresh during the first load joins it', () async {
      final c = makeContainer();
      c.read(insightProgressProvider);

      await c.read(insightProgressProvider.notifier).refresh();

      expect(entryRepo.insightProgressFetches, hasLength(1));
      expect(c.read(insightProgressProvider).hasValue, isTrue);
    });

    test(
      'a failing refresh keeps the last progress and never throws',
      () async {
        final c = makeContainer();
        await c.read(insightProgressProvider.future);
        entryRepo.insightProgressError = Exception('offline');

        await c.read(insightProgressProvider.notifier).refresh();

        expect(
          c.read(insightProgressProvider).value,
          const InsightProgress(activeDays: 2, gutFeelingEntries: 1),
        );
      },
    );

    test('signed out: no progress, nothing fetched', () async {
      final c = makeContainer(userId: null);

      final progress = await c.read(insightProgressProvider.future);

      expect(progress.activeDays, 0);
      expect(progress.gutFeelingEntries, 0);
      expect(entryRepo.insightProgressFetches, isEmpty);
    });
  });
}
