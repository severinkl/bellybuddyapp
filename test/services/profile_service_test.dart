import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/services/profile_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

/// Stubs [filter] so that `await filter` resolves with an empty list.
/// Used for upsert/update/delete where we only care the call completes.
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
  late ProfileService service;

  setUp(() {
    client = MockSupabaseClient();
    service = ProfileService(client);
  });

  group('ProfileService.fetchByUserId', () {
    test('returns UserProfile when row exists', () async {
      final filter = mockSelect(client, table: 'profiles');
      when(() => filter.eq(any(), any())).thenAnswer((_) => filter);

      final settled = settleMaybeSingle({
        'user_id': testUserId,
        'birth_year': 1990,
        'gender': 'male',
        'height': 180,
        'weight': 75,
        'diet': 'Keine Einschränkungen',
        'symptoms': ['Blähungen'],
        'intolerances': <String>[],
        'auth_method': 'email',
        'reminder_times': ['18:00'],
        'timezone': 'Europe/Berlin',
        'fructose_triggers': <String>[],
        'lactose_triggers': <String>[],
        'histamin_triggers': <String>[],
        'reminders_enabled': true,
        'daily_summary_enabled': true,
        'push_enabled': false,
        'daily_summary_time': '20:00',
        'fcm_token': null,
        'last_inactivity_nudge': null,
      });
      when(() => filter.maybeSingle()).thenAnswer((_) => settled);

      final result = await service.fetchByUserId(testUserId);

      expect(result, isNotNull);
      expect(result!.userId, testUserId);
      expect(result.birthYear, 1990);
      expect(result.gender, 'male');
    });

    test('returns null when no row found', () async {
      final filter = mockSelect(client, table: 'profiles');
      when(() => filter.eq(any(), any())).thenAnswer((_) => filter);

      final settled = settleMaybeSingle(null);
      when(() => filter.maybeSingle()).thenAnswer((_) => settled);

      final result = await service.fetchByUserId(testUserId);

      expect(result, isNull);
    });

    test('passes userId to eq filter', () async {
      final filter = mockSelect(client, table: 'profiles');
      when(() => filter.eq(any(), any())).thenAnswer((_) => filter);

      final settled = settleMaybeSingle(null);
      when(() => filter.maybeSingle()).thenAnswer((_) => settled);

      await service.fetchByUserId(testUserId);

      verify(() => filter.eq('user_id', testUserId)).called(1);
    });
  });

  group('ProfileService.upsert', () {
    test('calls upsert with data and onConflict user_id', () async {
      final filter = mockUpsert(client, table: 'profiles');
      _stubFilterFuture(filter);

      final data = {'user_id': testUserId, 'birth_year': 1990};
      await service.upsert(data);

      verify(
        () => client.from('profiles').upsert(data, onConflict: 'user_id'),
      ).called(1);
    });

    test('completes without error on success', () async {
      final filter = mockUpsert(client, table: 'profiles');
      _stubFilterFuture(filter);

      await expectLater(service.upsert({'user_id': testUserId}), completes);
    });
  });

  group('ProfileService.update', () {
    test('calls update on profiles table and filters by user_id', () async {
      final filter = mockUpdate(client, table: 'profiles');
      when(() => filter.eq(any(), any())).thenAnswer((_) => filter);
      _stubFilterFuture(filter);

      final data = {'birth_year': 1991};
      await service.update(testUserId, data);

      verify(() => client.from('profiles').update(data)).called(1);
      verify(() => filter.eq('user_id', testUserId)).called(1);
    });

    test('propagates errors thrown by supabase', () async {
      final filter = mockUpdate(client, table: 'profiles');
      when(() => filter.eq(any(), any())).thenThrow(Exception('db error'));

      await expectLater(
        service.update(testUserId, {'birth_year': 1991}),
        throwsException,
      );
    });
  });
}
