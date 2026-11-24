import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/services/buddy/care_meters.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/utils/gut_feeling_rating.dart';

const _h3 = Duration(hours: 3);

DateTime _t(int h, [int m = 0, int d = 23]) => DateTime(2026, 11, d, h, m);

void main() {
  group('awakeBetween', () {
    test('counts the awake time on one day', () {
      expect(
        awakeBetween(_t(10), _t(13, 30)),
        const Duration(hours: 3, minutes: 30),
      );
    });
    test('skips the night', () {
      expect(awakeBetween(_t(21), _t(8, 0, 24)), const Duration(hours: 2));
      expect(awakeBetween(_t(23), _t(6, 59, 24)), Duration.zero);
      expect(
        awakeBetween(_t(21, 0, 21), _t(8, 0, 23)),
        const Duration(hours: 17),
      );
    });
    test('is zero when to is not after from', () {
      expect(awakeBetween(_t(12), _t(10)), Duration.zero);
      expect(awakeBetween(_t(12), _t(12)), Duration.zero);
    });
    test('across the DST switches', () {
      expect(
        awakeBetween(DateTime(2026, 3, 28, 21), DateTime(2026, 3, 29, 8)),
        const Duration(hours: 2),
      );
      expect(
        awakeBetween(DateTime(2026, 10, 24, 21), DateTime(2026, 10, 25, 8)),
        const Duration(hours: 2),
      );
    });
    test('a UTC instant equals its local twin', () {
      final t = _t(10);
      final u = _t(15);
      expect(awakeBetween(t.toUtc(), u), awakeBetween(t, u));
    });
  });

  group('meterLevel', () {
    test('floor, full and linear drain', () {
      final now = _t(14);
      expect(meterLevel(null, now, _h3), 0.15);
      expect(meterLevel(now, now, _h3), 1.0);
      expect(meterLevel(_t(12, 30), now, _h3), closeTo(0.575, 0.005));
      expect(meterLevel(_t(11), now, _h3), closeTo(0.15, 0.005));
      expect(meterLevel(_t(4, 0, 22), now, _h3), 0.15);
    });
    test('a future entry keeps the meter full', () {
      expect(meterLevel(_t(18), _t(14), _h3), 1.0);
    });
    test('the night pause holds a level', () {
      final last = _t(21);
      expect(meterLevel(last, _t(23, 59), _h3), closeTo(0.717, 0.005));
      expect(meterLevel(last, _t(6, 59, 24), _h3), closeTo(0.717, 0.005));
      expect(meterLevel(last, _t(7, 30, 24), _h3), closeTo(0.575, 0.005));
    });
    test('food and Bauchgefühl drains', () {
      expect(
        meterLevel(_t(13), _t(14), const Duration(hours: 5)),
        closeTo(0.83, 0.005),
      );
      expect(
        meterLevel(_t(9, 15), _t(14), const Duration(hours: 5)),
        closeTo(0.1925, 0.005),
      );
      expect(
        meterLevel(_t(8), _t(14), const Duration(hours: 24)),
        closeTo(0.7875, 0.005),
      );
    });
  });

  group('careAgo', () {
    final now = _t(14);
    test('ranges', () {
      expect(careAgo(_t(13, 55), now), 'gerade eben');
      expect(careAgo(_t(13, 35), now), 'vor 25 Min');
      expect(careAgo(_t(10, 59), now), 'vor 3 Std');
      expect(careAgo(_t(20, 0, 22), now), 'gestern');
      expect(careAgo(_t(14, 0, 20), now), 'vor 3 Tagen');
    });
    test('careAgo of a later time today', () {
      expect(careAgo(_t(18), now), 'um 18:00');
      expect(careAgo(_t(9, 5).add(const Duration(hours: 10)), now), 'um 19:05');
    });
    test('across midnight', () {
      expect(careAgo(_t(23, 50, 22), _t(0, 30)), 'vor 40 Min');
    });
  });

  group('CareLog', () {
    final now = _t(14);
    final log = CareLog(
      lastMealAt: _t(13),
      lastDrinkAt: _t(12),
      lastGutFeelingAt: _t(8),
      lastToiletAt: _t(23, 0, 22),
      lastGutFeelingLevel: GutFeelingRatingLevel.values.first,
    );
    test('lastAt per need', () {
      expect(log.lastAt(CareNeed.food), _t(13));
      expect(log.lastAt(CareNeed.drink), _t(12));
      expect(log.lastAt(CareNeed.gutFeeling), _t(8));
      expect(log.lastAt(CareNeed.toilet), _t(23, 0, 22));
    });
    test('loggedOn and anyOn', () {
      expect(CareLog(lastToiletAt: _t(8)).loggedOn(CareNeed.toilet, now), true);
      expect(log.loggedOn(CareNeed.toilet, now), false);
      expect(CareLog(lastToiletAt: _t(8)).anyOn(now), true);
      expect(const CareLog().anyOn(now), false);
    });
    test('value equality', () {
      expect(CareLog(lastMealAt: _t(13)), CareLog(lastMealAt: _t(13)));
      expect(
        CareLog(lastMealAt: _t(13)).hashCode,
        CareLog(lastMealAt: _t(13)).hashCode,
      );
      expect(CareLog(lastMealAt: _t(13)) == CareLog(lastMealAt: _t(12)), false);
    });
  });

  group('CareMeters', () {
    final now = _t(14);
    test('at', () {
      final m = CareMeters.at(
        CareLog(
          lastMealAt: _t(13),
          lastDrinkAt: _t(12, 30),
          lastGutFeelingAt: _t(8),
        ),
        now,
      );
      expect(m.food, closeTo(0.83, 0.005));
      expect(m.drink, closeTo(0.575, 0.005));
      expect(m.gutFeeling, closeTo(0.7875, 0.005));
      expect(m.level(CareNeed.toilet), isNull);
      expect(m.level(CareNeed.drink), m.drink);
      expect(m.lowest, CareNeed.drink);
    });
    test('lowest ties go to food', () {
      expect(CareMeters.at(const CareLog(), now).lowest, CareNeed.food);
    });
    test('value equality', () {
      expect(
        CareMeters.at(const CareLog(), now),
        CareMeters.at(const CareLog(), now),
      );
    });
  });

  group('CareCopy', () {
    final now = _t(14);
    test('looLine', () {
      expect(CareCopy.looLine(CareLog(lastToiletAt: _t(11)), now), 'vor 3 Std');
      expect(
        CareCopy.looLine(CareLog(lastToiletAt: _t(11, 0, 22)), now),
        'heute noch nicht',
      );
      expect(CareCopy.looLine(const CareLog(), now), CareCopy.notToday);
    });
    test('spoken', () {
      expect(
        CareCopy.spoken(CareNeed.drink, CareLog(lastDrinkAt: _t(13)), now),
        'zuletzt vor 1 Std',
      );
      expect(
        CareCopy.spoken(CareNeed.drink, const CareLog(), now),
        CareCopy.notYet,
      );
      expect(
        CareCopy.spoken(CareNeed.toilet, const CareLog(), now),
        CareCopy.notToday,
      );
      expect(
        CareCopy.spoken(CareNeed.toilet, CareLog(lastToiletAt: _t(11)), now),
        'zuletzt vor 3 Std',
      );
    });
  });
}
