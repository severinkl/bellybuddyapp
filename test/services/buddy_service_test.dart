import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/services/buddy_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

void main() {
  late MockSupabaseClient client;
  late BuddyService service;

  setUp(() {
    client = MockSupabaseClient();
    service = BuddyService(client);
  });

  test('fetchByUserId returns raw map and filters by user_id', () async {
    final filter = mockSelect(client, table: 'buddy_state');
    when(() => filter.eq(any(), any())).thenAnswer((_) => filter);
    when(
      () => filter.maybeSingle(),
    ).thenAnswer((_) => settleMaybeSingle({'user_id': testUserId}));

    final result = await service.fetchByUserId(testUserId);

    expect(result, {'user_id': testUserId});
    verify(() => filter.eq('user_id', testUserId)).called(1);
  });

  test('fetchByUserId returns null when no row', () async {
    final filter = mockSelect(client, table: 'buddy_state');
    when(() => filter.eq(any(), any())).thenAnswer((_) => filter);
    when(() => filter.maybeSingle()).thenAnswer((_) => settleMaybeSingle(null));

    expect(await service.fetchByUserId(testUserId), isNull);
  });

  test('upsert uses onConflict user_id', () async {
    final filter = mockUpsert(client, table: 'buddy_state');
    when(
      () => filter.then<dynamic>(any(), onError: any(named: 'onError')),
    ).thenAnswer((inv) {
      final onValue = inv.positionalArguments[0] as Function;
      return Future<PostgrestList>.value([]).then((v) => onValue(v));
    });

    final data = {'user_id': testUserId, 'name': 'Buddy'};
    await service.upsert(data);

    verify(
      () => client.from('buddy_state').upsert(data, onConflict: 'user_id'),
    ).called(1);
  });
}
