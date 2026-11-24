import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/insight_rules.dart';
import 'package:belly_buddy/models/insight_source.dart';
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

  group('fetchInsightSource', () {
    test('fetchInsightSource window', () async {
      const source = InsightSource(
        meals: [],
        gutFeelings: [],
        activityInstants: [],
      );
      when(
        () => queryService.fetchInsightSource(
          userId: any(named: 'userId'),
          since: any(named: 'since'),
          mealsSince: any(named: 'mealsSince'),
        ),
      ).thenAnswer((_) async => source);

      final result = await repo.fetchInsightSource(
        userId: 'user-123',
        now: DateTime(2026, 11, 23, 9, 41),
      );

      expect(result, same(source));
      verify(
        () => queryService.fetchInsightSource(
          userId: 'user-123',
          since: DateTime(2026, 10, 25),
          mealsSince: DateTime(2026, 10, 24),
        ),
      ).called(1);
    });

    test('meals reach back as far as the insights look before an '
        'entry', () async {
      when(
        () => queryService.fetchInsightSource(
          userId: any(named: 'userId'),
          since: any(named: 'since'),
          mealsSince: any(named: 'mealsSince'),
        ),
      ).thenAnswer(
        (_) async => const InsightSource(
          meals: [],
          gutFeelings: [],
          activityInstants: [],
        ),
      );

      await repo.fetchInsightSource(
        userId: 'user-123',
        now: DateTime(2026, 11, 23, 9, 41),
      );

      verify(
        () => queryService.fetchInsightSource(
          userId: 'user-123',
          since: DateTime(2026, 10, 25),
          mealsSince: DateTime(2026, 10, 25).subtract(InsightRules.mealsBefore),
        ),
      ).called(1);
    });
  });
}
