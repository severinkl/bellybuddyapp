import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/journey_rewards.dart';

/// [json] as it comes back from storage: encoded and decoded again.
Object? _stored(Map<String, Object?> json) => jsonDecode(jsonEncode(json));

void main() {
  const full = JourneyRewards(
    earnedDay: 5,
    patternsFreed: true,
    picks: {
      1: RecipePick(id: 'a', title: 'Reispfanne'),
      3: RecipePick(id: 'b', title: 'Kartoffelsuppe'),
      5: RecipePick(id: 'c', title: 'Karottensalat', matched: ['Karotte']),
    },
    tipOffer: TipOffer.declined,
    firstTip: FirstTipState.failed,
  );

  group('JourneyRewards JSON', () {
    test('round-trips with all fields', () {
      expect(full.toJson(), {
        'earned': 5,
        'freed': true,
        'picks': {
          '1': {'id': 'a', 'title': 'Reispfanne', 'matched': <String>[]},
          '3': {'id': 'b', 'title': 'Kartoffelsuppe', 'matched': <String>[]},
          '5': {
            'id': 'c',
            'title': 'Karottensalat',
            'matched': ['Karotte'],
          },
        },
        'tipOffer': 'declined',
        'firstTip': 'failed',
      });
      expect(JourneyRewards.fromJson(_stored(full.toJson())), full);
    });

    test('the defaults round-trip, with null answers', () {
      const fresh = JourneyRewards();
      expect(fresh.toJson(), {
        'earned': 0,
        'freed': false,
        'picks': <String, Object?>{},
        'tipOffer': null,
        'firstTip': null,
      });
      expect(JourneyRewards.fromJson(_stored(fresh.toJson())), fresh);
    });

    test('another shape reads null', () {
      expect(JourneyRewards.fromJson('nope'), isNull);
      expect(JourneyRewards.fromJson(null), isNull);
      expect(JourneyRewards.fromJson({'earned': 'x'}), isNull);
      expect(JourneyRewards.fromJson({'freed': true}), isNull);
    });

    test('only earned is needed; the rest falls back', () {
      expect(
        JourneyRewards.fromJson({'earned': 2}),
        const JourneyRewards(earnedDay: 2),
      );
      expect(
        JourneyRewards.fromJson({'earned': 2, 'freed': 'yes', 'picks': []}),
        const JourneyRewards(earnedDay: 2),
      );
    });

    test('an unknown answer reads null', () {
      final read = JourneyRewards.fromJson({
        'earned': 2,
        'tipOffer': 'later',
        'firstTip': 'maybe',
      });
      expect(read!.tipOffer, isNull);
      expect(read.firstTip, isNull);
    });

    test('a bad pick is skipped, the others kept', () {
      final read = JourneyRewards.fromJson({
        'earned': 5,
        'picks': {
          '1': {'id': 1},
          'drei': {'id': 'x', 'title': 'X'},
          '3': 'nope',
          '5': {'id': 'c', 'title': 'Karottensalat'},
        },
      });
      expect(read!.picks, {
        5: const RecipePick(id: 'c', title: 'Karottensalat'),
      });
    });

    test('earned is clamped to 0–7', () {
      expect(JourneyRewards.fromJson({'earned': -3})!.earnedDay, 0);
      expect(JourneyRewards.fromJson({'earned': 12})!.earnedDay, 7);
      expect(JourneyRewards.fromJson({'earned': 7})!.earnedDay, 7);
    });

    test('picks only under the recipe days 1, 3 and 5', () {
      final read = JourneyRewards.fromJson({
        'earned': 7,
        'picks': {
          for (final day in ['0', '1', '2', '3', '4', '5', '6', '7'])
            day: {'id': 'r$day', 'title': 'Rezept $day'},
        },
      });
      expect(read!.picks.keys, unorderedEquals([1, 3, 5]));
      expect(read.picks[1], const RecipePick(id: 'r1', title: 'Rezept 1'));
    });
  });

  group('RecipePick JSON', () {
    test('round-trips', () {
      const pick = RecipePick(
        id: 'c',
        title: 'Karottensalat',
        matched: ['Karotte', 'Reis'],
      );
      expect(pick.toJson(), {
        'id': 'c',
        'title': 'Karottensalat',
        'matched': ['Karotte', 'Reis'],
      });
      expect(RecipePick.fromJson(_stored(pick.toJson())), pick);
    });

    test('another shape reads null; non-string matched names are dropped', () {
      expect(RecipePick.fromJson('nope'), isNull);
      expect(RecipePick.fromJson({'id': 'c'}), isNull);
      expect(RecipePick.fromJson({'title': 'C'}), isNull);
      expect(
        RecipePick.fromJson({
          'id': 'c',
          'title': 'C',
          'matched': ['Reis', 3],
        }),
        const RecipePick(id: 'c', title: 'C', matched: ['Reis']),
      );
    });
  });

  group('value equality', () {
    test('equal values are equal, with equal hash codes', () {
      final copy = JourneyRewards.fromJson(_stored(full.toJson()))!;
      expect(copy, full);
      expect(copy.hashCode, full.hashCode);
      expect(
        const RecipePick(id: 'c', title: 'C', matched: ['Reis']).hashCode,
        RecipePick(id: 'c', title: 'C', matched: ['Reis'].toList()).hashCode,
      );
    });

    test('any field makes a difference', () {
      expect(full.copyWith(earnedDay: 6), isNot(full));
      expect(full.copyWith(patternsFreed: false), isNot(full));
      expect(full.copyWith(picks: const {}), isNot(full));
      expect(full.copyWith(tipOffer: TipOffer.offered), isNot(full));
      expect(full.copyWith(firstTip: FirstTipState.done), isNot(full));
      expect(
        const RecipePick(id: 'c', title: 'C', matched: ['Reis']),
        isNot(const RecipePick(id: 'c', title: 'C', matched: ['Karotte'])),
      );
    });

    test('copyWith keeps what it is not given', () {
      expect(full.copyWith(), full);
      final next = full.copyWith(earnedDay: 6);
      expect(next.patternsFreed, isTrue);
      expect(next.picks, full.picks);
      expect(next.tipOffer, TipOffer.declined);
      expect(next.firstTip, FirstTipState.failed);
    });
  });
}
