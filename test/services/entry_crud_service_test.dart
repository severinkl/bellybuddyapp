import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/services/entry_crud_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

/// Stubs [filter] so that `await filter` resolves with an empty list.
void _stubFilterFuture(MockPostgrestFilterBuilder filter) {
  when(
    () => filter.then<dynamic>(any(), onError: any(named: 'onError')),
  ).thenAnswer((inv) {
    final onValue = inv.positionalArguments[0] as Function;
    return Future<PostgrestList>.value([]).then((v) => onValue(v));
  });
}

void main() {
  late MockSupabaseClient client;
  late EntryCrudService service;

  setUp(() {
    client = MockSupabaseClient();
    service = EntryCrudService(client);
  });

  group('EntryCrudService.insert', () {
    test('sets user_id from userId param', () async {
      final filter = mockInsert(client, table: 'meal_entries');
      _stubFilterFuture(filter);

      final data = <String, dynamic>{'title': 'Test'};
      await service.insert('meal_entries', data, userId: testUserId);

      expect(data['user_id'], testUserId);
    });

    test('removes id before inserting', () async {
      final filter = mockInsert(client, table: 'meal_entries');
      _stubFilterFuture(filter);

      final data = <String, dynamic>{
        'id': 'should-be-removed',
        'title': 'Test',
      };
      await service.insert('meal_entries', data, userId: testUserId);

      expect(data.containsKey('id'), isFalse);
    });

    test('removes created_at before inserting', () async {
      final filter = mockInsert(client, table: 'meal_entries');
      _stubFilterFuture(filter);

      final data = <String, dynamic>{
        'created_at': '2026-01-01',
        'title': 'Test',
      };
      await service.insert('meal_entries', data, userId: testUserId);

      expect(data.containsKey('created_at'), isFalse);
    });

    test('rethrows exceptions from supabase', () async {
      final queryBuilder = MockSupabaseQueryBuilder();
      when(() => client.from('meal_entries')).thenAnswer((_) => queryBuilder);
      when(
        () => queryBuilder.insert(any()),
      ).thenThrow(Exception('insert fail'));

      await expectLater(
        service.insert('meal_entries', {'title': 'X'}, userId: testUserId),
        throwsException,
      );
    });
  });

  group('EntryCrudService.update', () {
    test('removes id before updating', () async {
      final filter = mockUpdate(client, table: 'meal_entries');
      when(() => filter.eq(any(), any())).thenAnswer((_) => filter);
      _stubFilterFuture(filter);

      final data = <String, dynamic>{'id': 'remove-me', 'title': 'Updated'};
      await service.update('meal_entries', 'entry-1', data);

      expect(data.containsKey('id'), isFalse);
    });

    test('removes user_id before updating', () async {
      final filter = mockUpdate(client, table: 'meal_entries');
      when(() => filter.eq(any(), any())).thenAnswer((_) => filter);
      _stubFilterFuture(filter);

      final data = <String, dynamic>{'user_id': 'remove-me', 'title': 'X'};
      await service.update('meal_entries', 'entry-1', data);

      expect(data.containsKey('user_id'), isFalse);
    });

    test('removes created_at before updating', () async {
      final filter = mockUpdate(client, table: 'meal_entries');
      when(() => filter.eq(any(), any())).thenAnswer((_) => filter);
      _stubFilterFuture(filter);

      final data = <String, dynamic>{'created_at': '2026-01-01', 'title': 'X'};
      await service.update('meal_entries', 'entry-1', data);

      expect(data.containsKey('created_at'), isFalse);
    });

    test('filters by id with eq', () async {
      final filter = mockUpdate(client, table: 'meal_entries');
      when(() => filter.eq(any(), any())).thenAnswer((_) => filter);
      _stubFilterFuture(filter);

      await service.update('meal_entries', 'entry-42', {'title': 'X'});

      verify(() => filter.eq('id', 'entry-42')).called(1);
    });

    test('rethrows exceptions from supabase', () async {
      final filter = mockUpdate(client, table: 'meal_entries');
      when(() => filter.eq(any(), any())).thenThrow(Exception('update fail'));

      await expectLater(
        service.update('meal_entries', 'entry-1', {'title': 'X'}),
        throwsException,
      );
    });
  });

  group('EntryCrudService.delete', () {
    test('calls delete and filters by id', () async {
      final filter = mockDelete(client, table: 'meal_entries');
      when(() => filter.eq(any(), any())).thenAnswer((_) => filter);
      _stubFilterFuture(filter);

      await service.delete('meal_entries', 'entry-7');

      verify(() => client.from('meal_entries').delete()).called(1);
      verify(() => filter.eq('id', 'entry-7')).called(1);
    });

    test('rethrows exceptions from supabase', () async {
      final filter = mockDelete(client, table: 'meal_entries');
      when(() => filter.eq(any(), any())).thenThrow(Exception('delete fail'));

      await expectLater(
        service.delete('meal_entries', 'entry-1'),
        throwsException,
      );
    });
  });

  group('EntryCrudService.deleteByType', () {
    void setupDelete(String table) {
      final filter = mockDelete(client, table: table);
      when(() => filter.eq(any(), any())).thenAnswer((_) => filter);
      _stubFilterFuture(filter);
    }

    test('resolves meal to meal_entries', () async {
      setupDelete('meal_entries');
      await service.deleteByType('meal', 'id-1');
      verify(() => client.from('meal_entries').delete()).called(1);
    });

    test('resolves toilet to toilet_entries', () async {
      setupDelete('toilet_entries');
      await service.deleteByType('toilet', 'id-2');
      verify(() => client.from('toilet_entries').delete()).called(1);
    });

    test('resolves gutFeeling to gut_feeling_entries', () async {
      setupDelete('gut_feeling_entries');
      await service.deleteByType('gutFeeling', 'id-3');
      verify(() => client.from('gut_feeling_entries').delete()).called(1);
    });

    test('resolves drink to drink_entries', () async {
      setupDelete('drink_entries');
      await service.deleteByType('drink', 'id-4');
      verify(() => client.from('drink_entries').delete()).called(1);
    });

    test('throws ArgumentError for unknown type', () {
      expect(
        () => service.deleteByType('unknown', 'id-5'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
