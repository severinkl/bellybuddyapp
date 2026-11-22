import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';

import '../helpers/mocks.dart';

void main() {
  group('SupabaseBuddyRepository', () {
    late MockBuddyService service;
    late SupabaseBuddyRepository repo;

    setUp(() {
      service = MockBuddyService();
      repo = SupabaseBuddyRepository(service);
    });

    test('fetch returns null on null map', () async {
      when(() => service.fetchByUserId(any())).thenAnswer((_) async => null);
      expect(await repo.fetch('u1'), isNull);
    });

    test('fetch retries a failing read by default', () async {
      var calls = 0;
      when(() => service.fetchByUserId('u1')).thenAnswer((_) async {
        if (++calls == 1) throw Exception('backend down');
        return {'user_id': 'u1', 'name': 'Bubu'};
      });

      // retryAsync waits 2 s before the second attempt.
      final s = await repo.fetch('u1');

      expect(s!.name, 'Bubu');
      expect(calls, 2);
    });

    test('fetch with retry: false fails after one attempt', () async {
      when(
        () => service.fetchByUserId('u1'),
      ).thenAnswer((_) async => throw Exception('backend down'));

      await expectLater(repo.fetch('u1', retry: false), throwsException);
      verify(() => service.fetchByUserId('u1')).called(1);
    });

    test('fetch parses row', () async {
      when(() => service.fetchByUserId('u1')).thenAnswer(
        (_) async => {
          'id': 'x',
          'user_id': 'u1',
          'name': 'Bubu',
          'saved_days': ['2026-11-20'],
          'last_saver_earned_on': '2026-11-14',
        },
      );
      final s = await repo.fetch('u1');
      expect(s!.name, 'Bubu');
      expect(s.savedDays, [DateTime(2026, 11, 20)]);
      expect(s.lastSaverEarnedOn, DateTime(2026, 11, 14));
    });

    test('save upserts with user_id, no id, UTC onboarding', () async {
      when(() => service.upsert(any())).thenAnswer((_) async {});
      await repo.save(
        'u1',
        BuddyState(
          id: 'row-id',
          name: 'Bubu',
          onboardingCompletedAt: DateTime.utc(2026, 11, 1, 10),
          lastSaverEarnedOn: DateTime(2026, 11, 14),
        ),
      );
      final data =
          verify(() => service.upsert(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(data['user_id'], 'u1');
      expect(data.containsKey('id'), isFalse);
      expect(data['name'], 'Bubu');
      expect(data['onboarding_completed_at'], '2026-11-01T10:00:00.000Z');
      expect(data['last_saver_earned_on'], '2026-11-14');
    });
  });

  group('LocalBuddyRepository', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('fetch null when empty', () async {
      expect(await const LocalBuddyRepository().fetch('u1'), isNull);
    });

    test('save then fetch round-trips', () async {
      const repo = LocalBuddyRepository();
      final state = BuddyState(
        name: 'Bubu',
        streakGoal: 7,
        savers: 1,
        savedDays: [DateTime(2026, 11, 20)],
      );
      await repo.save('u1', state);
      expect(await repo.fetch('u1'), state.copyWith(userId: 'u1'));
      expect(await repo.fetch('u2'), isNull);
    });
  });
}
