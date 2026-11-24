import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/config/constants.dart';

import 'package:belly_buddy/models/insights.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/services/buddy/care_meters.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/services/buddy/log_moment.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';

DateTime _t(int h, [int d = 23]) => DateTime(2026, 11, d, h);

final _now = _t(14);

/// Trinken's level now after a drink at [last] (its math is
/// care_meters_test's).
double _drinkAt14(DateTime last) =>
    meterLevel(last, _now, AppConstants.careDrinkDrain);

void main() {
  group('logMomentFor: the level before and with the entry', () {
    test('drink last at 13:00, logged now: from its level to full', () {
      final m = logMomentFor(
        kind: EntryKind.drink,
        trackedAt: _now,
        care: CareLog(lastDrinkAt: _t(13)),
        now: _now,
      );
      expect(m.need, CareNeed.drink);
      expect(m.from, _drinkAt14(_t(13)));
      expect(m.to, 1.0);
    });

    test('a back-dated entry older than the last changes nothing', () {
      final m = logMomentFor(
        kind: EntryKind.drink,
        trackedAt: _t(11),
        care: CareLog(lastDrinkAt: _t(13)),
        now: _now,
      );
      expect(m.from, _drinkAt14(_t(13)));
      expect(m.to, m.from);
    });

    test('an entry for later today charges to full', () {
      final m = logMomentFor(
        kind: EntryKind.drink,
        trackedAt: _t(18),
        care: CareLog(lastDrinkAt: _t(13)),
        now: _now,
      );
      expect(m.to, 1.0);
    });

    test('Klo has no level; the moment carries what was logged and how', () {
      final m = logMomentFor(
        kind: EntryKind.toilet,
        trackedAt: _now,
        care: CareLog(lastToiletAt: _t(9)),
        now: _now,
        sentiment: LogSentiment.bad,
      );
      expect(m.kind, EntryKind.toilet);
      expect(m.sentiment, LogSentiment.bad);
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
      kind: EntryKind.meal,
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
    Insights insights(int days, int gutFeelings) =>
        lockedInsights(activeDays: days, gutFeelings: gutFeelings);

    String? line({
      Insights? insights,
      CareLog care = const CareLog(),
      DateTime? trackedAt,
      LogSentiment sentiment = LogSentiment.good,
    }) => logMomentFor(
      kind: EntryKind.gutFeeling,
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

    /// Locked insights whose journey ends on [lastDay].
    Insights journeyTo(DateTime lastDay) => lockedInsights(
      activeDays: 2,
      gutFeelings: 1,
      journey: [
        JourneyDay(DateTime(2026, 11, 20), gutFeeling: true),
        JourneyDay(lastDay, gutFeeling: false),
      ],
    );

    test('on a day the insights already count, the days stay', () {
      expect(
        line(
          insights: journeyTo(DateTime(2026, 11, 23)),
          care: CareLog(lastMealAt: _t(8)),
        ),
        'Notiert! Noch 5 Tage, dann schau ich nach ersten Mustern.',
      );
    });

    test("insights that don't count today's earlier meal yet (their refresh "
        'failed): today is one more day', () {
      expect(
        line(
          insights: journeyTo(DateTime(2026, 11, 22)),
          care: CareLog(lastMealAt: _t(8)),
        ),
        'Notiert! Noch 4 Tage, dann schau ich nach ersten Mustern.',
      );
    });

    test('insights that count today while Home has not loaded it: the days '
        'stay', () {
      expect(
        line(insights: journeyTo(DateTime(2026, 11, 23))),
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
          kind: EntryKind.meal,
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
