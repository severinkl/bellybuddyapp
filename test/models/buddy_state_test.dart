import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/models/buddy_state.dart';

void main() {
  test('defaults', () {
    const s = BuddyState();
    expect(s.name, 'Buddy');
    expect(s.savers, 0);
    expect(s.savedDays, isEmpty);
    expect(s.lastMilestone, 0);
  });

  test('fromJson reads saved_days as local-midnight dates', () {
    final s = BuddyState.fromJson({
      'user_id': 'u',
      'name': 'Bubu',
      'streak_goal': 7,
      'savers': 2,
      'saved_days': ['2026-11-20'],
      'last_milestone': 3,
      'onboarding_completed_at': '2026-11-01T10:00:00Z',
    });
    expect(s.savedDays, [DateTime(2026, 11, 20)]);
    expect(s.streakGoal, 7);
    expect(s.onboardingCompletedAt, DateTime.utc(2026, 11, 1, 10));
  });

  test('toJson round-trips and writes yyyy-MM-dd', () {
    final s = BuddyState(
      userId: 'u',
      streakGoal: 14,
      savedDays: [DateTime(2026, 1, 5)],
    );
    final json = s.toJson();
    expect(json['saved_days'], ['2026-01-05']);
    expect(json['user_id'], 'u');
    expect(BuddyState.fromJson(json), s);
  });
}
