import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/services/buddy/care_meters.dart';
import 'package:belly_buddy/services/buddy/care_now.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/utils/gut_feeling_rating.dart';
import 'package:belly_buddy/widgets/buddy/buddy_pose.dart';

DateTime _t(int h, [int m = 0]) => DateTime(2026, 11, 23, h, m);

void main() {
  final log = CareLog(
    lastMealAt: _t(13),
    lastDrinkAt: _t(9),
    lastGutFeelingAt: _t(8),
    lastToiletAt: _t(11),
    lastGutFeelingLevel: GutFeelingRatingLevel.mittel,
  );

  test('what Home shows of the log at a minute', () {
    final now = CareNow.at(log, _t(14));

    expect(now.at, _t(14));
    expect(now.log, log);
    expect(now.meters, CareMeters.at(log, _t(14)));
    expect(now.mood, deriveBuddyMood(log, _t(14)));
    expect(now.mood, BuddyMood.hungry);
    expect(now.action, nextCareAction(log, _t(14)));
    expect(now.action, CareAction.drink);
    expect(now.looLine, 'vor 3 Std');
    for (final need in CareNeed.values) {
      expect(
        now.spoken(need),
        CareCopy.spoken(need, log, _t(14)),
        reason: '$need',
      );
    }
    expect(now.spoken(CareNeed.gutFeeling), 'zuletzt vor 6 Std, Mittel');
  });

  test('equal while nothing it shows changes', () {
    // In the night pause the meters hold; every line still says „vor 2 Std"
    // or more, unchanged within the hour.
    final night = CareLog(lastMealAt: _t(21));
    expect(CareNow.at(night, _t(23)), CareNow.at(night, _t(23, 30)));
    expect(
      CareNow.at(night, _t(23)).hashCode,
      CareNow.at(night, _t(23, 30)).hashCode,
    );
  });

  test('not equal once a line ages, a meter moves or the face changes', () {
    // Klo's „vor 3 Std" becomes „vor 4 Std" with every meter at the floor.
    final floor = CareLog(lastToiletAt: _t(11));
    expect(CareNow.at(floor, _t(14)), isNot(CareNow.at(floor, _t(15))));
    expect(CareNow.at(log, _t(14)), isNot(CareNow.at(log, _t(14, 1))));
    final good = CareLog(
      lastMealAt: _t(13),
      lastDrinkAt: _t(9),
      lastGutFeelingAt: _t(8),
      lastToiletAt: _t(11),
      lastGutFeelingLevel: GutFeelingRatingLevel.gut,
    );
    expect(CareNow.at(log, _t(14)), isNot(CareNow.at(good, _t(14))));
  });
}
