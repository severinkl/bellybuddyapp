import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/services/buddy/buddy_copy.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/services/journey/journey_copy.dart';
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

  test('an announcement line for each he says; none for those ending in '
      'a sheet or page', () {
    String? line(BuddyAnnouncement a, {bool weeklyTipsOn = false}) =>
        BuddyCopy.announcementLine(a, weeklyTipsOn: weeklyTipsOn);
    expect(line(BuddyAnnouncement.saverUsed), BuddyCopy.saverUsed);
    expect(line(BuddyAnnouncement.streakBroken), BuddyCopy.streakBroken);
    expect(line(BuddyAnnouncement.saverEarned), BuddyCopy.saverEarned);
    expect(line(BuddyAnnouncement.tipsArrived), BuddyCopy.tipsArrived);
    for (final on in [true, false]) {
      expect(
        line(BuddyAnnouncement.firstTipFailed, weeklyTipsOn: on),
        JourneyCopy.firstTipFailed(weeklyTipsOn: on),
      );
    }
    for (final a in [
      BuddyAnnouncement.goalReached,
      BuddyAnnouncement.weeklyTipsOffer,
      BuddyAnnouncement.firstTipOffer,
      BuddyAnnouncement.journeyReward,
      BuddyAnnouncement.patternsUnlocked,
    ]) {
      expect(line(a), isNull, reason: '$a');
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

  test('the care buttons speak of Essen, Trinken, Bauchgefühl eintragen', () {
    expect(BuddyCopy.careButton(CareAction.feed), 'Essen eintragen');
    expect(BuddyCopy.careButton(CareAction.drink), 'Trinken eintragen');
    expect(
      BuddyCopy.careButton(CareAction.gutFeeling),
      'Bauchgefühl eintragen',
    );
    expect(BuddyCopy.careButton(CareAction.lunch), 'Mittagessen eintragen');
  });

  test('the care buttons are words only: the icon leads them', () {
    final words = RegExp(r'^[\p{L} ]+$', unicode: true);
    for (final a in CareAction.values) {
      expect(BuddyCopy.careButton(a), matches(words), reason: '$a');
    }
  });

  test('care lines invite, they never say a meal is missing', () {
    for (final pool in BuddyCopy.care.values) {
      for (final line in pool) {
        expect(line, isNot(contains('fehlt')), reason: line);
      }
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
