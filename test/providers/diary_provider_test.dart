import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/diary_provider.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  late MockEntryRepository mockRepo;

  setUp(() {
    mockRepo = MockEntryRepository();
  });

  ProviderContainer makeContainer({String? userId = testUserId}) =>
      createContainer(
        overrides: [
          entryRepositoryProvider.overrideWithValue(mockRepo),
          currentUserIdProvider.overrideWithValue(userId),
        ],
      );

  group('diaryEntriesProvider', () {
    test('returns diary entries for the given date', () async {
      final queryResult = testEntryQueryResult();
      when(
        () => mockRepo.fetchForDate(
          userId: any(named: 'userId'),
          date: any(named: 'date'),
          ordered: any(named: 'ordered'),
        ),
      ).thenAnswer((_) async => queryResult);

      final container = makeContainer();
      final date = DateTime(2026, 3, 25);

      final result = await container.read(diaryEntriesProvider(date).future);

      // testEntryQueryResult has 1 meal + 1 toilet + 1 gut feeling + 1 drink = 4
      expect(result, hasLength(4));
    });

    test('returns empty list when userId is null', () async {
      final container = makeContainer(userId: null);
      final date = DateTime(2026, 3, 25);

      final result = await container.read(diaryEntriesProvider(date).future);

      expect(result, isEmpty);
      verifyNever(
        () => mockRepo.fetchForDate(
          userId: any(named: 'userId'),
          date: any(named: 'date'),
          ordered: any(named: 'ordered'),
        ),
      );
    });

    test('calls repo and repo throws → verifies repo was called', () async {
      when(
        () => mockRepo.fetchForDate(
          userId: any(named: 'userId'),
          date: any(named: 'date'),
          ordered: any(named: 'ordered'),
        ),
      ).thenThrow(Exception('db error'));

      final container = makeContainer();
      final date = DateTime(2026, 3, 25);

      // Start listening so the provider is kept alive
      AsyncValue<List<DiaryEntry>>? lastState;
      container.listen(diaryEntriesProvider(date), (_, next) {
        lastState = next;
      });

      // Pump microtasks to let the future settle
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Repo was called
      verify(
        () => mockRepo.fetchForDate(
          userId: testUserId,
          date: date,
          ordered: any(named: 'ordered'),
        ),
      ).called(1);

      // The last state transition included an error
      expect(lastState?.hasError, isTrue);
    });
  });

  group('diaryDateProvider', () {
    test('defaults to today (date-only)', () {
      final container = makeContainer();
      final date = container.read(diaryDateProvider);
      final now = DateTime.now();

      expect(date.year, equals(now.year));
      expect(date.month, equals(now.month));
      expect(date.day, equals(now.day));
      expect(date.hour, equals(0));
      expect(date.minute, equals(0));
      expect(date.second, equals(0));
    });

    test('set() changes the date', () {
      final container = makeContainer();
      final newDate = DateTime(2026, 1, 15);

      container.read(diaryDateProvider.notifier).set(newDate);

      expect(container.read(diaryDateProvider), equals(newDate));
    });
  });
}
