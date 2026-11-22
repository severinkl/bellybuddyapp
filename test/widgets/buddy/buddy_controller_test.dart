import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:belly_buddy/widgets/buddy/buddy_actions.dart';
import 'package:belly_buddy/widgets/buddy/buddy_controller.dart';
import 'package:belly_buddy/widgets/buddy/buddy_pose.dart';
import 'package:flutter_test/flutter_test.dart';

const _step = 1 / 60;

/// Ticks [c] at 60 fps for [seconds] and returns every frame produced.
List<BuddyFrame> _run(BuddyController c, double seconds) => [
  for (var i = 0; i < (seconds * 60).round(); i++) (c..tick(_step)).frame,
];

/// Number of distinct blinks (rising edges through [threshold]).
int _blinks(Iterable<BuddyFrame> frames, {double threshold = 0.75}) {
  var count = 0;
  var closed = false;
  for (final f in frames) {
    if (!closed && f.blink >= threshold) count++;
    closed = f.blink >= threshold;
  }
  return count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initial frame shows the constructor mood before any tick', () {
    final c = BuddyController(mood: BuddyMood.sad);
    expect(c.mood, BuddyMood.sad);
    expect(c.frame.t, 0);
    expect(c.frame.face.closeTo(FacePose.forMood(BuddyMood.sad)), isTrue);
    expect(c.currentAction, isNull);
    expect(c.bubble, isNull);
    expect(c.reducedMotion, isFalse);
  });

  test('tick clamps dt to [0, 0.05] and notifies listeners', () {
    final c = BuddyController();
    var notified = 0;
    c.addListener(() => notified++);
    c.tick(1);
    expect(c.frame.t, closeTo(0.05, 1e-12));
    c.tick(-1);
    expect(c.frame.t, closeTo(0.05, 1e-12));
    c.tick(double.nan);
    expect(c.frame.t, closeTo(0.05, 1e-12));
    expect(notified, 3);
  });

  test('mood blend converges to the target pose', () {
    final c = BuddyController()..mood = BuddyMood.sad;
    _run(c, 3);
    expect(
      c.frame.face.closeTo(FacePose.forMood(BuddyMood.sad), eps: 0.01),
      isTrue,
    );
  });

  test('play(eat) shows a bulge, then the action ends', () {
    final c = BuddyController()..play(BuddyAction.eat);
    expect(c.currentAction, BuddyAction.eat);
    _run(c, 2);
    expect(c.frame.bulgeAmt, greaterThan(0));
    expect(c.frame.bulgePoint, isNotNull);
    _run(c, 3);
    expect(c.currentAction, isNull);
    expect(c.frame.bulgeAmt, 0);
    expect(c.frame.bulgePoint, isNull);
  });

  test('food image is on the frame while eat runs and cleared after', () {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder);
    final img = recorder.endRecording().toImageSync(1, 1);
    addTearDown(img.dispose);

    final c = BuddyController()..play(BuddyAction.eat, food: img);
    _run(c, 0.3);
    expect(c.frame.food, same(img));
    expect(c.frame.foodPos, isNotNull);
    _run(c, 3.5);
    expect(c.frame.food, same(img));
    _run(c, 0.3);
    expect(c.currentAction, isNull);
    expect(c.frame.food, isNull);

    // A later action without food does not resurrect the image.
    c.play(BuddyAction.eat);
    _run(c, 0.3);
    expect(c.frame.food, isNull);
  });

  test('play restarts a running action', () {
    final c = BuddyController()..play(BuddyAction.eat);
    _run(c, 3);
    c.play(BuddyAction.eat);
    _run(c, 2);
    expect(c.currentAction, BuddyAction.eat);
    c.play(BuddyAction.poke);
    expect(c.currentAction, BuddyAction.poke);
    _run(c, 1);
    expect(c.currentAction, isNull);
  });

  test('rapid celebrate x5 settles back to the happy face (R2: 3 s)', () {
    final c = BuddyController();
    for (var i = 0; i < 5; i++) {
      c
        ..play(BuddyAction.celebrate)
        ..tick(0.02);
    }
    expect(c.currentAction, BuddyAction.celebrate);
    _run(c, 3);
    expect(c.currentAction, isNull);
    expect(
      c.frame.face.closeTo(FacePose.forMood(BuddyMood.happy), eps: 0.05),
      isTrue,
    );
  });

  test('action face override blends in rather than snapping', () {
    final c = BuddyController()..play(BuddyAction.celebrate);
    final frames = _run(c, 0.5);
    // celebrate wants open 0.75; happy has open 0.
    expect(frames.first.face.open, lessThan(0.3));
    expect(frames.last.face.open, closeTo(0.75, 0.02));
    for (var i = 1; i < frames.length; i++) {
      final d = (frames[i].face.open - frames[i - 1].face.open).abs();
      expect(d, lessThan(0.2), reason: 'frame $i');
    }
  });

  test('reduced motion freezes the body but keeps face and sparkles', () {
    final c = BuddyController()
      ..reducedMotion = true
      ..mood = BuddyMood.energetic
      ..play(BuddyAction.celebrate);
    final frames = _run(c, 1);
    for (final f in frames) {
      expect(f.ty, 0);
      expect(f.tx, 0);
      expect(f.sx, 1);
      expect(f.sy, 1);
      expect(f.rot, 0);
      expect(f.sway, 0);
      expect(f.face.sway, 0);
      expect(f.face.hop, 0);
      expect(f.face.shake, 0);
      expect(f.face.rumble, 0);
    }
    // Face override still cross-fades in, sparkles still play.
    expect(frames.last.face.open, greaterThan(0.6));
    expect(frames.any((f) => f.sparkleP >= 0), isTrue);
  });

  test('reduced motion hides food fall and bulge, damps breath', () {
    final rm = BuddyController(mood: BuddyMood.zen)..reducedMotion = true;
    final full = BuddyController(mood: BuddyMood.zen);
    rm.play(BuddyAction.eat);
    full.play(BuddyAction.eat);
    final a = _run(rm, 3.9);
    final b = _run(full, 3.9);
    for (var i = 0; i < a.length; i++) {
      expect(a[i].foodPos, isNull);
      expect(a[i].bulgeAmt, 0);
      expect(a[i].breath, closeTo(b[i].breath * 0.3, 1e-9));
    }
    expect(b.any((f) => f.foodPos != null), isTrue);
    expect(b.any((f) => f.bulgeAmt > 0.5), isTrue);
    expect(b.map((f) => f.breath.abs()).reduce(math.max), greaterThan(0.01));
  });

  test('nervous shakes, energetic hops, hungry rumbles', () {
    final nervous = _run(BuddyController(mood: BuddyMood.nervous), 2);
    expect(nervous.map((f) => f.tx.abs()).reduce(math.max), greaterThan(3));

    final energetic = _run(BuddyController(mood: BuddyMood.energetic), 2);
    expect(energetic.map((f) => f.ty).reduce(math.min), lessThan(-50));

    final hungry = BuddyController(mood: BuddyMood.hungry);
    final h = _run(hungry, 6);
    final base = FacePose.forMood(BuddyMood.hungry);
    expect(h.map((f) => f.rot.abs()).reduce(math.max), greaterThan(0.005));
    expect(h.map((f) => f.sway).reduce(math.max), greaterThan(base.sway + 3));
    // Bursts, not a constant wiggle: quiet between them.
    final quiet = h.where((f) => f.t % 3 > 1.0 && f.t % 3 < 2.9);
    for (final f in quiet) {
      expect(f.rot.abs(), lessThan(1e-9));
      expect(f.sway, closeTo(base.sway, 1e-9));
    }
  });

  test('say shows a bubble for its duration and bumps bubbleId', () {
    final c = BuddyController();
    expect(c.bubbleId, 0);
    c.say('Hallo');
    expect(c.bubble, 'Hallo');
    expect(c.bubbleId, 1);
    _run(c, 2);
    expect(c.bubble, 'Hallo');
    _run(c, 1);
    expect(c.bubble, isNull);
    c
      ..say('Hi', duration: const Duration(milliseconds: 500))
      ..say('Na du?');
    expect(c.bubble, 'Na du?');
    expect(c.bubbleId, 3);
    _run(c, 1);
    expect(c.bubble, 'Na du?');
  });

  test('lookAt steers the gaze toward the point', () {
    final c = BuddyController()..lookAt(const Offset(467, 2000));
    _run(c, 0.5);
    expect(c.frame.gaze.dy, greaterThan(0.5));
  });

  test('lookAt expires after its hold', () {
    final c = BuddyController()
      ..lookAt(
        const Offset(467, 2000),
        hold: const Duration(milliseconds: 300),
      );
    _run(c, 0.3);
    expect(c.frame.gaze.dy, greaterThan(0.5));
    // Idle wandering targets dy <= 0.5 + gazeY(-0.2) for happy.
    _run(c, 1);
    expect(c.frame.gaze.dy, lessThan(0.4));
  });

  test('action gaze target beats lookAt', () {
    final c = BuddyController()
      ..lookAt(const Offset(467, 2000))
      ..play(BuddyAction.eat);
    _run(c, 0.5);
    // Food falls from above the eyes.
    expect(c.frame.gaze.dy, lessThan(-0.3));
  });

  test('think forces the gaze up-left, even over lookAt', () {
    final c = BuddyController()
      ..lookAt(const Offset(467, 2000))
      ..play(BuddyAction.think);
    _run(c, 0.6);
    final want = const Offset(-0.7, -0.8) / const Offset(-0.7, -0.8).distance;
    expect((c.frame.gaze - want).distance, lessThan(0.02));
  });

  test('gaze stays within the unit disc', () {
    final c = BuddyController(mood: BuddyMood.sad);
    final frames = [
      ..._run(c..lookAt(const Offset(-5000, 9000)), 2),
      ..._run(c..play(BuddyAction.think), 2),
      ..._run(c..play(BuddyAction.eat), 4),
      ..._run(c, 10),
    ];
    for (final f in frames) {
      expect(f.gaze.distance, lessThanOrEqualTo(1 + 1e-9));
    }
  });

  test('same seed gives identical blink sequences; blinks happen', () {
    final a = BuddyController(seed: 7);
    final b = BuddyController(seed: 7);
    final fa = _run(a, 20).map((f) => f.blink).toList();
    final fb = _run(b, 20).map((f) => f.blink).toList();
    expect(fa, fb);
    final n = _blinks(_run(BuddyController(seed: 7), 20));
    // Every 2–5.5 s (sometimes double) over 20 s.
    expect(n, inInclusiveRange(4, 16));
  });

  test('closed lids (lidTop >= 0.9) suppress blinking', () {
    final c = BuddyController(mood: BuddyMood.zen);
    expect(_blinks(_run(c, 20), threshold: 0.01), 0);
  });

  test('a mood or override with lidTop < 0.9 still blinks', () {
    expect(
      _blinks(_run(BuddyController(mood: BuddyMood.sleepy), 20)),
      greaterThanOrEqualTo(3),
    );
    // relief overrides lidTop to 0.45 and is kept running the whole time.
    final c = BuddyController();
    final frames = <BuddyFrame>[];
    for (var i = 0; i < 10; i++) {
      c.play(BuddyAction.relief);
      frames.addAll(_run(c, 2));
    }
    expect(_blinks(frames), greaterThanOrEqualTo(3));
  });

  test('wakeUp blinks twice as the eyes open', () {
    final c = BuddyController(mood: BuddyMood.sleepy);
    _run(c, 3);
    c.play(BuddyAction.wakeUp);
    final frames = _run(c, 2.7);
    expect(c.currentAction, isNull);
    // Exactly the two scripted blinks, both while the lids open (1.0–1.5 s).
    expect(_blinks(frames, threshold: 0.01), 2);
    final during = frames.where((f) => f.t - 3 >= 0.95 && f.t - 3 < 1.55);
    expect(_blinks(during), 2);
  });

  test('hitTest uses the undeformed silhouette', () {
    final c = BuddyController();
    expect(c.hitTest(const Offset(900, 420)), isTrue);
    expect(c.hitTest(const Offset(20, 20)), isFalse);
  });

  test('hearts and sparkles come from the action', () {
    final c = BuddyController()..play(BuddyAction.hug);
    _run(c, 0.8);
    expect(c.frame.hearts, greaterThan(0));
    expect(c.frame.sparkleP, -1);
    c.play(BuddyAction.celebrate);
    _run(c, 0.8);
    expect(c.frame.hearts, 0);
    expect(c.frame.sparkleP, greaterThanOrEqualTo(0));
  });
}
