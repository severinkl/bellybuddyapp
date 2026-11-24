import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/insight_progress.dart';
import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/services/buddy/care_meters.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/services/buddy/log_moment.dart';

import '../../helpers/fakes.dart';

DateTime _t(int h, [int d = 23]) => DateTime(2026, 11, d, h);

final _now = _t(14);

void main() {
  group('logMomentFor: the level before and with the entry', () {
    test('drink last at 13:00, logged now: from 0.717 to full', () {
      final m = logMomentFor(
        need: CareNeed.drink,
        trackedAt: _now,
        care: CareLog(lastDrinkAt: _t(13)),
        now: _now,
      );
      expect(m.need, CareNeed.drink);
      expect(m.from, closeTo(0.717, 0.005));
      expect(m.to, closeTo(1.0, 0.005));
    });

    test('a back-dated entry older than the last changes nothing', () {
      final m = logMomentFor(
        need: CareNeed.drink,
        trackedAt: _t(11),
        care: CareLog(lastDrinkAt: _t(13)),
        now: _now,
      );
      expect(m.from, closeTo(0.717, 0.005));
      expect(m.to, m.from);
    });

    test('an entry for later today charges to full', () {
      final m = logMomentFor(
        need: CareNeed.drink,
        trackedAt: _t(18),
        care: CareLog(lastDrinkAt: _t(13)),
        now: _now,
      );
      expect(m.to, 1.0);
    });

    test('Klo has no level', () {
      final m = logMomentFor(
        need: CareNeed.toilet,
        trackedAt: _now,
        care: CareLog(lastToiletAt: _t(9)),
        now: _now,
      );
      expect(m.need, CareNeed.toilet);
      expect(m.from, isNull);
      expect(m.to, isNull);
    });
  });

  group('logMomentFor: the day the entry ignites', () {
    LogMoment moment({
      DateTime? trackedAt,
      CareLog care = const CareLog(),
      bool withStatus = true,
      int streak = 4,
      bool todayCounted = false,
    }) => logMomentFor(
      need: CareNeed.food,
      trackedAt: trackedAt ?? _now,
      care: care,
      now: _now,
      buddy: withStatus
          ? buddyStatus(streak: streak, todayCounted: todayCounted)
          : null,
    );

    test("today's first entry makes the streak one longer", () {
      expect(moment().ignitesDay, 5);
    });

    test('a day already counted ignites nothing', () {
      expect(moment(todayCounted: true).ignitesDay, isNull);
    });

    test('an entry dated yesterday ignites nothing', () {
      expect(moment(trackedAt: _t(20, 22)).ignitesDay, isNull);
    });

    test('an entry already logged today ignites nothing', () {
      expect(moment(care: CareLog(lastToiletAt: _t(8))).ignitesDay, isNull);
    });

    test('without a status nothing ignites', () {
      expect(moment(withStatus: false).ignitesDay, isNull);
    });

    test('no streak yet: day 1', () {
      expect(moment(streak: 0).ignitesDay, 1);
    });
  });

  group("logMomentFor: the Buddy's feedback line", () {
    Insights insights(int days, int gutFeelings) => Insights(
      progress: InsightProgress(
        activeDays: days,
        gutFeelingEntries: gutFeelings,
      ),
      calendar: const [],
      goodDays: const DayColumn(days: 0),
      hardDays: const DayColumn(days: 0),
      noticed: const [],
      pick: const NothingYetPick(),
    );

    String? line({
      Insights? insights,
      CareLog care = const CareLog(),
      DateTime? trackedAt,
      LogSentiment sentiment = LogSentiment.good,
    }) => logMomentFor(
      need: CareNeed.gutFeeling,
      trackedAt: trackedAt ?? _now,
      care: care,
      now: _now,
      insights: insights,
      sentiment: sentiment,
    ).buddyLine;

    test("today's first good Bauchgefühl while locked says how far it is", () {
      expect(
        line(insights: insights(2, 1)),
        'Notiert! Noch 4 Tage, dann schau ich nach ersten Mustern.',
      );
    });

    test('on a day that already counts, the days stay', () {
      expect(
        line(
          insights: insights(2, 1),
          care: CareLog(lastMealAt: _t(8)),
        ),
        'Notiert! Noch 5 Tage, dann schau ich nach ersten Mustern.',
      );
    });

    test('a neutral one says it too', () {
      expect(
        line(insights: insights(2, 1), sentiment: LogSentiment.neutral),
        isNotNull,
      );
    });

    test('a second Bauchgefühl today: no line', () {
      expect(
        line(
          insights: insights(2, 1),
          care: CareLog(lastGutFeelingAt: _t(8)),
        ),
        isNull,
      );
    });

    test('a bad one: no line', () {
      expect(
        line(insights: insights(2, 1), sentiment: LogSentiment.bad),
        isNull,
      );
    });

    test('unlocked: no line', () {
      expect(line(insights: insights(7, 3)), isNull);
    });

    test('the entry that unlocks: no line', () {
      expect(line(insights: insights(6, 2)), isNull);
    });

    test('no insights: no line', () {
      expect(line(), isNull);
    });

    test('a back-dated Bauchgefühl: no line', () {
      expect(line(insights: insights(2, 1), trackedAt: _t(20, 22)), isNull);
    });

    test('another need: no line', () {
      expect(
        logMomentFor(
          need: CareNeed.food,
          trackedAt: _now,
          care: const CareLog(),
          now: _now,
          insights: insights(2, 1),
        ).buddyLine,
        isNull,
      );
    });
  });
}
