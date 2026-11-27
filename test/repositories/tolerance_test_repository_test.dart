import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/repositories/tolerance_test_repository.dart';

import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

void main() {
  late MockSupabaseClient client;
  late ToleranceTestRepository repo;

  setUp(() {
    client = MockSupabaseClient();
    repo = ToleranceTestRepository(client, () => 'u1');
  });

  /// `update(...).eq(...).eq(...).select('id')` answering [rows].
  void answer(List<Map<String, dynamic>> rows) {
    final fb = mockUpdate(client, table: 'tolerance_tests');
    when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
    when(
      () => fb.select(any()),
    ).thenAnswer((_) => SettlableFilterBuilder(Future.value(rows)));
  }

  test('complete: the updated row confirms it', () async {
    answer([
      {'id': 't1'},
    ]);
    await repo.complete('t1');
  });

  test('complete: no row updated (no longer active, not visible) is a '
      'failure', () async {
    answer([]);
    await expectLater(repo.complete('t1'), throwsA(isA<TestNotEnded>()));
  });

  test('stop: no row updated is a failure too', () async {
    answer([]);
    await expectLater(repo.stop('t1'), throwsA(isA<TestNotEnded>()));
  });
}
