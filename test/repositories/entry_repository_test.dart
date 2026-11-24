import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';

import '../helpers/mocks.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockEntryCrudService crudService;
  late MockEntryQueryService queryService;
  late EntryRepository repo;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    crudService = MockEntryCrudService();
    queryService = MockEntryQueryService();
    repo = EntryRepository(crudService, queryService);
  });

  group('fetchForDate', () {
    test('delegates to queryService.fetchEntriesForDateRange', () async {
      final date = DateTime(2026, 3, 25);
      final queryResult = testEntryQueryResult();
      when(
        () => queryService.fetchEntriesForDateRange(
          userId: any(named: 'userId'),
          date: any(named: 'date'),
          ordered: any(named: 'ordered'),
        ),
      ).thenAnswer((_) async => queryResult);

      final result = await repo.fetchForDate(userId: 'user-123', date: date);

      expect(result, equals(queryResult));
      verify(
        () => queryService.fetchEntriesForDateRange(
          userId: 'user-123',
          date: date,
          ordered: false,
        ),
      ).called(1);
    });

    test('passes ordered flag to queryService', () async {
      final date = DateTime(2026, 3, 25);
      final queryResult = testEntryQueryResult();
      when(
        () => queryService.fetchEntriesForDateRange(
          userId: any(named: 'userId'),
          date: any(named: 'date'),
          ordered: any(named: 'ordered'),
        ),
      ).thenAnswer((_) async => queryResult);

      await repo.fetchForDate(userId: 'user-123', date: date, ordered: true);

      verify(
        () => queryService.fetchEntriesForDateRange(
          userId: 'user-123',
          date: date,
          ordered: true,
        ),
      ).called(1);
    });
  });

  group('insertEntry', () {
    test('delegates to crudService.insert with userId', () async {
      when(
        () => crudService.insert(any(), any(), userId: any(named: 'userId')),
      ).thenAnswer((_) async {});

      final data = <String, dynamic>{'title': 'Testmahlzeit'};
      await repo.insertEntry('meal_entries', data, userId: 'user-123');

      verify(
        () => crudService.insert('meal_entries', data, userId: 'user-123'),
      ).called(1);
    });
  });

  group('updateEntry', () {
    test('delegates to crudService.update', () async {
      when(
        () => crudService.update(any(), any(), any()),
      ).thenAnswer((_) async {});

      final data = <String, dynamic>{'title': 'Aktualisiert'};
      await repo.updateEntry('meal_entries', 'entry-id-1', data);

      verify(
        () => crudService.update('meal_entries', 'entry-id-1', data),
      ).called(1);
    });
  });

  group('deleteEntry', () {
    test('delegates to crudService.delete', () async {
      when(() => crudService.delete(any(), any())).thenAnswer((_) async {});

      await repo.deleteEntry('meal_entries', 'entry-id-1');

      verify(() => crudService.delete('meal_entries', 'entry-id-1')).called(1);
    });
  });

  group('deleteByType', () {
    test('delegates to crudService.deleteByType', () async {
      when(
        () => crudService.deleteByType(any(), any()),
      ).thenAnswer((_) async {});

      await repo.deleteByType('meal', 'entry-id-1');

      verify(() => crudService.deleteByType('meal', 'entry-id-1')).called(1);
    });
  });

  group('fetchActivityDays', () {
    test(
      'maps wall-clock times to their dates and dedupes same days',
      () async {
        final since = DateTime(2026, 11, 1);
        when(
          () => queryService.fetchTrackedAtSince(
            userId: any(named: 'userId'),
            since: any(named: 'since'),
          ),
        ).thenAnswer(
          (_) async => [
            DateTime(2026, 11, 21, 23, 59),
            DateTime(2026, 11, 21, 0, 1),
            DateTime(2026, 11, 22, 8),
          ],
        );

        final days = await repo.fetchActivityDays(
          userId: 'user-123',
          since: since,
        );

        expect(days, {DateTime(2026, 11, 21), DateTime(2026, 11, 22)});
        verify(
          () => queryService.fetchTrackedAtSince(
            userId: 'user-123',
            since: since,
          ),
        ).called(1);
      },
    );
  });

  group('fetchInsightProgress', () {
    test(
      'fetchInsightProgress counts distinct days and gut entries in 30 days',
      () async {
        final now = DateTime(2026, 11, 23, 9);
        DateTime daysAgo(int days, int hour) =>
            DateTime(2026, 11, 23 - days, hour);
        // Meal, drink and Klo entries; gut-feeling entries are entries too.
        final others = [
          daysAgo(1, 8),
          daysAgo(1, 12),
          daysAgo(1, 19),
          daysAgo(5, 10),
        ];
        final gutFeelings = [daysAgo(1, 9), daysAgo(1, 20), daysAgo(40, 9)];
        // The backend's view: only rows since `since`, of the asked tables.
        when(
          () => queryService.fetchTrackedAtSince(
            userId: any(named: 'userId'),
            since: any(named: 'since'),
            until: any(named: 'until'),
            tables: any(named: 'tables'),
          ),
        ).thenAnswer((inv) async {
          final since = inv.namedArguments[#since] as DateTime;
          final tables = inv.namedArguments[#tables] as Iterable<String>?;
          final rows = tables == null
              ? [...others, ...gutFeelings]
              : [
                  if (tables.contains('gut_feeling_entries')) ...gutFeelings,
                  if (tables.length > 1) ...others,
                ];
          return [
            for (final t in rows)
              if (!t.isBefore(since)) t.toUtc(),
          ];
        });

        final progress = await repo.fetchInsightProgress(
          userId: 'user-123',
          now: now,
        );

        expect(
          progress,
          const InsightProgress(activeDays: 2, gutFeelingEntries: 2),
        );
        // The window: 30 local days, today included.
        final windowStart = DateTime(2026, 10, 25);
        verify(
          () => queryService.fetchTrackedAtSince(
            userId: 'user-123',
            since: windowStart,
          ),
        ).called(1);
        verify(
          () => queryService.fetchTrackedAtSince(
            userId: 'user-123',
            since: windowStart,
            tables: ['gut_feeling_entries'],
          ),
        ).called(1);
      },
    );
  });
}
