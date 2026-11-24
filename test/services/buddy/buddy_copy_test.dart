import 'package:belly_buddy/services/buddy/buddy_copy.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/widgets/buddy/buddy_pose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every pool has at least 3 variants', () {
    final pools = [
      BuddyCopy.meal,
      BuddyCopy.drink,
      BuddyCopy.relief,
      BuddyCopy.toiletBad,
      BuddyCopy.gutGood,
      BuddyCopy.gutNeutral,
      BuddyCopy.gutBad,
    ];
    for (final p in pools) {
      expect(p.length, greaterThanOrEqualTo(3));
    }
    for (final m in BuddyMood.values) {
      expect(BuddyCopy.mood[m]!.length, greaterThanOrEqualTo(3));
    }
  });

  test('fill substitutes placeholders', () {
    expect(
      BuddyCopy.fill('Hi {name}, {streak} Tage', name: 'Bubu', streak: 3),
      'Hi Bubu, 3 Tage',
    );
  });

  test('every care action has a button label and at least 2 lines', () {
    for (final a in CareAction.values) {
      expect(BuddyCopy.careButton(a), isNotEmpty, reason: '$a');
      expect(BuddyCopy.care[a]!.length, greaterThanOrEqualTo(2), reason: '$a');
    }
  });

  test('care lines fit the dashboard bubble', () {
    for (final pool in BuddyCopy.care.values) {
      for (final line in pool) {
        expect(line.length, lessThanOrEqualTo(60), reason: line);
      }
    }
  });
}
