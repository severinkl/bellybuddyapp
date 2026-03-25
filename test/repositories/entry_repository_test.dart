import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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
}
