import 'dart:math' as math;

import 'package:belly_buddy/widgets/buddy/buddy_actions.dart';
import 'package:belly_buddy/widgets/buddy/buddy_pose.dart';
import 'package:flutter_test/flutter_test.dart';

const _base = FacePose();
const _step = 1 / 60;

/// Actions whose first/landing frames snap on purpose (ruling R1).
const _snapping = {BuddyAction.celebrate, BuddyAction.poke};

double _secs(BuddyAction a) => buddyActionDuration(a).inMicroseconds / 1e6;

/// Samples at 1/60 s from one step before the start until the action has
/// ended, so the first and the last entry are neutral.
List<ActionSample> _timeline(BuddyAction a, [FacePose base = _base]) {
  final n = (_secs(a) * 60).ceil();
  return [
    sampleAction(a, -_step, base),
    for (var i = 0; i <= n; i++) sampleAction(a, i / 60, base),
  ];
}

void _expectNeutral(ActionSample s, String reason) {
  expect(s.tx, 0, reason: reason);
  expect(s.ty, 0, reason: reason);
  expect(s.sx, 1, reason: reason);
  expect(s.sy, 1, reason: reason);
  expect(s.rot, 0, reason: reason);
  expect(s.face, isNull, reason: reason);
  expect(s.bulgePoint, isNull, reason: reason);
  expect(s.bulgeAmt, 0, reason: reason);
  expect(s.bulgeIsWater, isFalse, reason: reason);
  expect(s.foodPos, isNull, reason: reason);
  expect(s.foodScale, 0, reason: reason);
  expect(s.sparkleP, -1, reason: reason);
  expect(s.hearts, 0, reason: reason);
}

double _max(Iterable<double> v) => v.reduce(math.max);
double _min(Iterable<double> v) => v.reduce(math.min);

void main() {
  test('durations', () {
    const ms = {
      BuddyAction.eat: 4000,
      BuddyAction.drink: 3000,
      BuddyAction.celebrate: 1800,
      BuddyAction.poke: 900,
      BuddyAction.wakeUp: 2600,
      BuddyAction.yawn: 1800,
      BuddyAction.wave: 1400,
      BuddyAction.relief: 2200,
      BuddyAction.hug: 1800,
      BuddyAction.nodYes: 900,
      BuddyAction.think: 1500,
    };
    expect(ms.keys.toSet(), BuddyAction.values.toSet());
    for (final a in BuddyAction.values) {
      expect(buddyActionDuration(a), Duration(milliseconds: ms[a]!));
    }
  });

  test('ActionSample.neutral', () {
    _expectNeutral(const ActionSample.neutral(), 'neutral');
  });

  test('every action is neutral outside its duration', () {
    for (final a in BuddyAction.values) {
      _expectNeutral(sampleAction(a, _secs(a), _base), '$a at duration');
      _expectNeutral(sampleAction(a, _secs(a) + 1, _base), '$a after');
      _expectNeutral(sampleAction(a, -0.1, _base), '$a at -0.1');
    }
  });

  test('scale stays within [0.8, 1.2]', () {
    for (final a in BuddyAction.values) {
      for (final s in _timeline(a)) {
        expect(s.sx, inInclusiveRange(0.8, 1.2), reason: '$a sx');
        expect(s.sy, inInclusiveRange(0.8, 1.2), reason: '$a sy');
      }
    }
  });

  test('transforms are continuous, from and back to neutral', () {
    for (final a in BuddyAction.values) {
      if (_snapping.contains(a)) continue;
      final tl = _timeline(a);
      for (var i = 1; i < tl.length; i++) {
        final p = tl[i - 1], s = tl[i];
        final at = 'at step $i';
        expect(
          (s.sx - p.sx).abs(),
          lessThanOrEqualTo(0.05),
          reason: '$a sx $at',
        );
        expect(
          (s.sy - p.sy).abs(),
          lessThanOrEqualTo(0.05),
          reason: '$a sy $at',
        );
        expect((s.tx - p.tx).abs(), lessThanOrEqualTo(15), reason: '$a tx $at');
        expect((s.ty - p.ty).abs(), lessThanOrEqualTo(15), reason: '$a ty $at');
        expect(
          (s.rot - p.rot).abs(),
          lessThanOrEqualTo(0.02),
          reason: '$a rot $at',
        );
      }
    }
  });

  group('eat (spike port)', () {
    test('food drops from y=-330 into the mouth', () {
      final s0 = sampleAction(BuddyAction.eat, 0, _base);
      expect(s0.foodPos, const Offset(430, -330));
      expect(s0.foodScale, 1);
      expect(s0.face!.open, closeTo(0.5, 1e-9));
      final s1 = sampleAction(BuddyAction.eat, 0.35, _base);
      expect(s1.foodPos!.dy, closeTo(-330 + 330 * 0.25, 1e-6));
      final s2 = sampleAction(BuddyAction.eat, 0.825, _base);
      expect(s2.foodPos!.dy, closeTo(50, 1e-6));
      expect(s2.foodScale, closeTo(0.5, 1e-6));
    });

    test('bulge travels the gut', () {
      final s = sampleAction(BuddyAction.eat, 2.0, _base);
      expect(s.bulgePoint, isNotNull);
      expect(s.bulgeAmt, greaterThan(0.5));
      expect(s.bulgeIsWater, isFalse);
      final early = sampleAction(BuddyAction.eat, 0.8, _base).bulgePoint!;
      final late = sampleAction(BuddyAction.eat, 3.1, _base).bulgePoint!;
      expect(late.dy, greaterThan(early.dy + 1000));
    });

    test('gulp face keeps heavy lids at most 0.15', () {
      final sleepy = FacePose.forMood(BuddyMood.sleepy);
      final s = sampleAction(BuddyAction.eat, 1.5, sleepy);
      expect(s.face!.lidTop, closeTo(0.15, 1e-9));
      expect(s.face!.zzz, sleepy.zzz);
    });

    test('happy hop of 70 at the end', () {
      final s = sampleAction(BuddyAction.eat, 3.6, _base);
      expect(s.ty, closeTo(-70, 1e-6));
      expect(s.face!.lidBottom, closeTo(0.55, 1e-9));
    });
  });

  test('drink: water bulge, no food', () {
    final s = sampleAction(BuddyAction.drink, 1.5, _base);
    expect(s.bulgeIsWater, isTrue);
    expect(s.bulgePoint, isNotNull);
    expect(s.bulgeAmt, greaterThan(0.5));
    expect(s.face!.smile, closeTo(0.9, 1e-9));
    expect(s.face!.lidBottom, closeTo(0.3, 1e-9));
    expect(sampleAction(BuddyAction.drink, 0.2, _base).bulgePoint, isNull);
    for (final x in _timeline(BuddyAction.drink)) {
      expect(x.foodPos, isNull);
      expect(x.foodScale, 0);
    }
    final hop = _timeline(BuddyAction.drink).where((x) => x.ty < -1);
    expect(hop, isNotEmpty);
    expect(_min(hop.map((x) => x.ty)), greaterThan(-70));
  });

  group('celebrate (spike port)', () {
    test('jumps 280 high with sparkles', () {
      expect(
        sampleAction(BuddyAction.celebrate, 0.45, _base).ty,
        lessThan(-200),
      );
      final peak = sampleAction(BuddyAction.celebrate, 0.44, _base);
      expect(peak.ty, closeTo(-280, 1e-6));
      final s = sampleAction(BuddyAction.celebrate, 0.8, _base);
      expect(s.sparkleP, greaterThanOrEqualTo(0));
      expect(s.sparkleP, closeTo(0.5 / 1.5, 1e-9));
      expect(sampleAction(BuddyAction.celebrate, 0.2, _base).sparkleP, -1);
    });

    test('anticipation squash and blush floor', () {
      final s = sampleAction(BuddyAction.celebrate, 0.18 - 1e-9, _base);
      expect(s.sy, closeTo(0.87, 1e-6));
      expect(s.sx, closeTo(1.09, 1e-6));
      final love = FacePose.forMood(BuddyMood.inLove);
      expect(sampleAction(BuddyAction.celebrate, 0.5, love).face!.blush, 1);
      expect(sampleAction(BuddyAction.celebrate, 0.5, _base).face!.blush, 0.6);
    });
  });

  test('poke: jelly wobble and giggle face', () {
    final s = sampleAction(BuddyAction.poke, 0, _base);
    expect(s.sy, closeTo(0.87, 1e-9));
    expect(s.sx, closeTo(1.104, 1e-9));
    expect(sampleAction(BuddyAction.poke, 0.3, _base).face!.lidBottom, 0.6);
    expect(sampleAction(BuddyAction.poke, 0.75, _base).face, isNull);
  });

  test('wakeUp: lids open with a stretch, blinks, happy hop', () {
    final sleepy = FacePose.forMood(BuddyMood.sleepy);
    expect(sampleAction(BuddyAction.wakeUp, 0, sleepy).face!.lidTop, 1);
    final s = sampleAction(BuddyAction.wakeUp, 0.5, sleepy);
    expect(s.sy, closeTo(1.06, 1e-6));
    expect(
      sampleAction(BuddyAction.wakeUp, 1.0 - 1e-9, sleepy).face!.lidTop,
      closeTo(0.6, 1e-6),
    );
    final blinks = [
      for (var t = 1.0; t < 1.3; t += 0.005)
        sampleAction(BuddyAction.wakeUp, t, sleepy).face!.lidTop,
    ];
    var peaks = 0;
    for (var i = 1; i < blinks.length - 1; i++) {
      if (blinks[i] > blinks[i - 1] && blinks[i] >= blinks[i + 1]) peaks++;
    }
    expect(peaks, 2);
    expect(_max(blinks), greaterThan(0.95));
    final awake = sampleAction(BuddyAction.wakeUp, 1.8, sleepy);
    expect(awake.face!.smile, 1);
    expect(awake.face!.open, closeTo(0.3, 1e-9));
    expect(awake.face!.zzz, 0);
    final tl = _timeline(BuddyAction.wakeUp, sleepy);
    expect(_min(tl.map((x) => x.ty)), lessThan(-30));
  });

  test('yawn: mouth opens to 0.9 with a stretch', () {
    final tl = _timeline(BuddyAction.yawn);
    final opens = tl.where((x) => x.face != null).map((x) => x.face!.open);
    expect(_max(opens), closeTo(0.9, 1e-3));
    expect(tl[1].face!.open, closeTo(0, 1e-9));
    expect(tl[tl.length - 2].face!.open, closeTo(0, 1e-3));
    expect(_max(tl.map((x) => x.sy)), closeTo(1.05, 1e-3));
    expect(sampleAction(BuddyAction.yawn, 0.9, _base).face!.lidTop, 0.5);
  });

  test('wave: two lean cycles of ±0.06 with a happy face', () {
    final tl = _timeline(BuddyAction.wave);
    final rots = tl.map((x) => x.rot).toList();
    expect(_max(rots), closeTo(0.06, 1e-3));
    expect(_min(rots), closeTo(-0.06, 1e-3));
    var flips = 0;
    for (var i = 1; i < rots.length; i++) {
      if (rots[i - 1] * rots[i] < 0) flips++;
    }
    expect(flips, 3);
    final f = sampleAction(BuddyAction.wave, 0.7, _base).face!;
    expect(f.smile, 1);
    expect(f.open, 0.25);
  });

  test('relief: squash to 0.9 then overshooting release', () {
    expect(sampleAction(BuddyAction.relief, 0.5, _base).sy, closeTo(0.9, 1e-6));
    final release = _timeline(BuddyAction.relief).skip(1 + 31).map((x) => x.sy);
    expect(_max(release), greaterThan(1.02));
    final f = sampleAction(BuddyAction.relief, 1.0, _base).face!;
    expect(f.lidTop, 0.45);
    expect(f.smile, 0.7);
  });

  test('hug: held squeeze with hearts and blush', () {
    final s = sampleAction(BuddyAction.hug, 0.8, _base);
    expect(s.hearts, greaterThan(0));
    expect(s.sx, closeTo(0.92, 1e-6));
    expect(s.sy, closeTo(1.04, 1e-6));
    expect(s.face!.blush, 1);
    expect(s.face!.lidBottom, 0.5);
    expect(s.face!.smile, 0.6);
    expect(sampleAction(BuddyAction.hug, 0.1, _base).hearts, 0);
  });

  test('nodYes: two bobs of 20 with a 0.97 squash', () {
    final tl = _timeline(BuddyAction.nodYes);
    expect(_min(tl.map((x) => x.ty)), closeTo(-20, 0.5));
    expect(_min(tl.map((x) => x.sy)), closeTo(0.97, 1e-3));
    var bobs = 0;
    for (var i = 1; i < tl.length; i++) {
      if (tl[i - 1].ty > -10 && tl[i].ty <= -10) bobs++;
    }
    expect(bobs, 2);
  });

  test('think: looks up with a slight tilt', () {
    final s = sampleAction(BuddyAction.think, 0.75, _base);
    expect(s.face!.gazeY, -0.8);
    expect(s.face!.smile, 0.2);
    expect(s.face!.mouthWidth, 0.6);
    expect(s.rot, closeTo(-0.03, 1e-6));
  });
}
