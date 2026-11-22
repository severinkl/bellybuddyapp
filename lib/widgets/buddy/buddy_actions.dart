/// One-shot Buddy actions expressed as pure functions of time.
///
/// [sampleAction] returns the body transform and effect state of an action at
/// a given time since its start. The controller blends [ActionSample.face]
/// over the mood pose and composes the transform with idle motion.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'buddy_geometry.dart';
import 'buddy_pose.dart';

enum BuddyAction {
  eat,
  drink,
  celebrate,
  poke,
  wakeUp,
  yawn,
  wave,
  relief,
  hug,
  nodYes,
  think,
}

Duration buddyActionDuration(BuddyAction a) => Duration(
  milliseconds: switch (a) {
    BuddyAction.eat => 4000,
    BuddyAction.drink => 3000,
    BuddyAction.celebrate => 1800,
    BuddyAction.poke => 900,
    BuddyAction.wakeUp => 2600,
    BuddyAction.yawn => 1800,
    BuddyAction.wave => 1400,
    BuddyAction.relief => 2200,
    BuddyAction.hug => 1800,
    BuddyAction.nodYes => 900,
    BuddyAction.think => 1500,
  },
);

/// An action's state at one instant. Transforms are in Buddy image space
/// (`tx`/`ty` in image px, `rot` in radians about the bottom centre).
class ActionSample {
  const ActionSample({
    this.tx = 0,
    this.ty = 0,
    this.sx = 1,
    this.sy = 1,
    this.rot = 0,
    this.face,
    this.bulgePoint,
    this.bulgeAmt = 0,
    this.bulgeIsWater = false,
    this.foodPos,
    this.foodScale = 0,
    this.sparkleP = -1,
    this.hearts = 0,
  });

  const ActionSample.neutral() : this();

  final double tx, ty, sx, sy, rot;

  /// Override pose to blend toward; null when the action leaves the face be.
  final FacePose? face;

  /// Centre of the gulp bulge on the gut centerline (image coords).
  final Offset? bulgePoint;

  /// Bulge strength 0..1 (the painter applies gain and falloff).
  final double bulgeAmt;
  final bool bulgeIsWater;

  /// Falling food position (image coords) and its scale 0..1.
  final Offset? foodPos;
  final double foodScale;

  /// Sparkle burst progress 0..1, or -1 when no sparkles are shown.
  final double sparkleP;

  /// Floating-hearts intensity 0..1.
  final double hearts;
}

/// Samples [a] at [t] seconds since it started. [base] is the current mood
/// pose that face overrides are derived from. Outside `0 <= t < duration`
/// the result is [ActionSample.neutral].
ActionSample sampleAction(BuddyAction a, double t, FacePose base) {
  final end = buddyActionDuration(a).inMicroseconds / 1e6;
  if (t < 0 || t >= end) return const ActionSample.neutral();
  return switch (a) {
    BuddyAction.eat => _eat(t, base),
    BuddyAction.drink => _drink(t, base),
    BuddyAction.celebrate => _celebrate(t, base),
    BuddyAction.poke => _poke(t, base),
    BuddyAction.wakeUp => _wakeUp(t, base),
    BuddyAction.yawn => _yawn(t, base),
    BuddyAction.wave => _wave(t, base),
    BuddyAction.relief => _relief(t, base),
    BuddyAction.hug => _hug(t, base),
    BuddyAction.nodYes => _nodYes(t, base),
    BuddyAction.think => _think(t, base),
  };
}

// ---------------------------------------------------------------------------
// Easing helpers. Every envelope is 0 at its ends so phases join seamlessly.
// ---------------------------------------------------------------------------

double _easeInOut(double p) =>
    p < 0.5 ? 2 * p * p : 1 - math.pow(-2 * p + 2, 2) / 2;

/// Smoothstep of `x` clamped to 0..1 (zero velocity at both ends).
double _smooth(double x) {
  final c = x.clamp(0.0, 1.0);
  return c * c * (3 - 2 * c);
}

/// Smooth 0→1 ramp between times [a] and [b].
double _ramp(double t, double a, double b) => _smooth((t - a) / (b - a));

/// sin² bump over 0..1 peaking at 0.5; 0 outside (zero velocity at the ends).
double _bell(double x) {
  if (x <= 0 || x >= 1) return 0;
  final s = math.sin(math.pi * x);
  return s * s;
}

/// Underdamped spring released from 1 at rest; decays toward 0.
double _spring(double d, double k, double w) =>
    math.exp(-k * d) * (math.cos(w * d) + k / w * math.sin(w * d));

double _lerp(double a, double b, double k) => a + (b - a) * k;

/// Mutable transform accumulator for building a sample.
class _Xf {
  double tx = 0, ty = 0, sx = 1, sy = 1, rot = 0;

  /// Positive [amt] squashes (shorter, wider); negative stretches.
  void squash(double amt, [double widen = 0.7]) {
    sy *= 1 - amt;
    sx *= 1 + amt * widen;
  }

  /// Cartoon hop at local time [d] of [dur] seconds: anticipation squash
  /// (first 20 %), airborne arc of [height] px with a stretch (middle 60 %),
  /// landing squash (last 20 %). At rest outside `0 < d < dur`.
  void hop(double d, double dur, double height, double sq) {
    if (d <= 0 || d >= dur) return;
    final p = d / dur;
    if (p < 0.2) {
      squash(sq * _bell(p / 0.2));
    } else if (p < 0.8) {
      final air = math.sin(math.pi * (p - 0.2) / 0.6);
      ty -= height * air;
      squash(-0.6 * sq * air, 0.5);
    } else {
      squash(sq * _bell((p - 0.8) / 0.2));
    }
  }

  ActionSample build({
    FacePose? face,
    Offset? bulgePoint,
    double bulgeAmt = 0,
    bool bulgeIsWater = false,
    Offset? foodPos,
    double foodScale = 0,
    double sparkleP = -1,
    double hearts = 0,
  }) => ActionSample(
    tx: tx,
    ty: ty,
    sx: sx,
    sy: sy,
    rot: rot,
    face: face,
    bulgePoint: bulgePoint,
    bulgeAmt: bulgeAmt,
    bulgeIsWater: bulgeIsWater,
    foodPos: foodPos,
    foodScale: foodScale,
    sparkleP: sparkleP,
    hearts: hearts,
  );
}

// ---------------------------------------------------------------------------
// Spike ports (tuned in the prototype; keep values in sync with the spike).
// ---------------------------------------------------------------------------

/// Food drops into the esophagus, a bulge travels down the gut, happy hop.
ActionSample _eat(double t, FacePose f) {
  Offset? foodPos;
  var foodScale = 0.0;
  Offset? bulgePoint;
  var bulgeAmt = 0.0;
  final x = _Xf();
  FacePose? face;

  if (t < 0.7) {
    final p = t / 0.7;
    foodPos = Offset(430, -330 + 330 * p * p);
    foodScale = 1;
    face = f.copyWith(
      open: 0.5,
      mouthWidth: 0.45,
      smile: 0.1,
      lidTop: 0,
      lidBottom: 0,
    );
  } else if (t < 0.95) {
    final p = (t - 0.7) / 0.25;
    foodPos = Offset(430, 20 + 60 * p);
    foodScale = 1 - p;
  }
  if (t >= 0.75 && t < 3.2) {
    final p = ((t - 0.75) / 2.45).clamp(0.0, 1.0);
    bulgePoint = pointAlongCenterline(_easeInOut(p));
    bulgeAmt =
        math.min(1.0, (t - 0.75) / 0.25) * math.min(1.0, (3.2 - t) / 0.3);
    face = f.copyWith(
      open: 0,
      smile: 0.8,
      mouthWidth: 0.75,
      lidTop: math.min(f.lidTop, 0.15),
      lidBottom: 0,
    );
  }
  if (t >= 3.2) {
    final p = (t - 3.2) / 0.8;
    x.ty -= 70 * math.sin(math.pi * p);
    face = f.copyWith(
      lidBottom: 0.55,
      smile: 1,
      open: 0.35,
      mouthWidth: 1,
      lidTop: 0,
      blush: 0.7,
    );
  }
  return x.build(
    face: face,
    bulgePoint: bulgePoint,
    bulgeAmt: bulgeAmt,
    foodPos: foodPos,
    foodScale: foodScale,
  );
}

/// Anticipation squash, 280 px jump with stretch, springy landing, sparkles.
ActionSample _celebrate(double t, FacePose f) {
  final x = _Xf();
  final face = f.copyWith(
    open: 0.75,
    smile: 1,
    mouthWidth: 1.1,
    lidTop: 0,
    lidBottom: t > 0.15 && t < 1.3 ? 0.55 : 0,
    blush: math.max(f.blush, 0.6),
  );
  if (t < 0.18) {
    final s = math.sin(math.pi / 2 * t / 0.18);
    x.sy *= 1 - 0.13 * s;
    x.sx *= 1 + 0.09 * s;
  } else if (t < 0.7) {
    final p = (t - 0.18) / 0.52;
    x.ty -= 4 * 280 * p * (1 - p);
    x.sy *= 1 + 0.1 * (1 - p) - 0.04;
    x.sx *= 1 - 0.05 * (1 - p);
    x.rot += 0.09 * math.sin(p * 2 * math.pi);
  } else {
    final d = t - 0.7;
    x.squash(0.15 * math.exp(-6 * d) * math.cos(17 * d));
  }
  return x.build(face: face, sparkleP: t > 0.3 ? (t - 0.3) / 1.5 : -1);
}

/// Jelly wobble with a giggle face (snaps on the tap frame by design).
ActionSample _poke(double t, FacePose f) {
  final x = _Xf()..squash(0.13 * math.exp(-7 * t) * math.cos(24 * t), 0.8);
  return x.build(
    face: t < 0.7
        ? f.copyWith(lidBottom: 0.6, smile: 1, open: 0.3, lidTop: 0)
        : null,
  );
}

// ---------------------------------------------------------------------------
// New actions.
// ---------------------------------------------------------------------------

/// A gulp, then a blue wave travels down the gut; ends with a tiny hop.
ActionSample _drink(double t, FacePose f) {
  final x = _Xf()
    ..squash(0.04 * _bell(t / 0.4))
    ..hop(t - 2.45, 0.5, 45, 0.05);
  Offset? bulgePoint;
  var bulgeAmt = 0.0;
  if (t >= 0.3 && t < 2.5) {
    bulgePoint = pointAlongCenterline(_easeInOut((t - 0.3) / 2.2));
    bulgeAmt = _ramp(t, 0.3, 0.55) * (1 - _ramp(t, 2.2, 2.5));
  }
  return x.build(
    face: f.copyWith(
      smile: 0.9,
      lidBottom: 0.3,
      open: 0.3 * _bell((t - 2.35) / 0.65),
    ),
    bulgePoint: bulgePoint,
    bulgeAmt: bulgeAmt,
    bulgeIsWater: true,
  );
}

/// Lids open during a slow stretch, two blinks, then a bright happy hop.
ActionSample _wakeUp(double t, FacePose f) {
  final x = _Xf()
    ..squash(-0.06 * _bell(t / 1.0), 0.5)
    ..hop(t - 1.45, 0.7, 70, 0.06);
  final FacePose face;
  if (t < 1.0) {
    face = f.copyWith(
      lidTop: _lerp(1, 0.6, _smooth(t / 1.0)),
      lidBottom: 0,
      smile: 0.3,
      open: 0.35 * _bell(t / 1.0),
      mouthWidth: 0.7,
      zzz: 0,
    );
  } else if (t < 1.3) {
    final rest = _lerp(0.6, 0, _ramp(t, 1.0, 1.3));
    final blink = _bell(((t - 1.0) % 0.15) / 0.15);
    face = f.copyWith(
      lidTop: rest + (1 - rest) * blink,
      lidBottom: 0,
      smile: 0.6,
      open: 0,
      mouthWidth: 0.85,
      zzz: 0,
    );
  } else {
    face = f.copyWith(
      lidTop: 0,
      lidBottom: 0.2,
      smile: 1,
      open: 0.3,
      mouthWidth: 1,
      blush: math.max(f.blush, 0.5),
      zzz: 0,
    );
  }
  return x.build(face: face);
}

/// Mouth opens wide with a stretch and a lean back, then settles.
ActionSample _yawn(double t, FacePose f) {
  final env = _ramp(t, 0.05, 0.75) * (1 - _ramp(t, 1.1, 1.6));
  final x = _Xf()
    ..squash(-0.05 * env, 0.5)
    ..squash(0.025 * _bell((t - 1.45) / 0.35))
    ..rot = -0.025 * env;
  return x.build(
    face: f.copyWith(
      open: 0.9 * env,
      lidTop: 0.5,
      smile: _lerp(f.smile, 0.2, env),
      mouthWidth: _lerp(f.mouthWidth, 0.7, env),
    ),
  );
}

/// Two side-to-side leans with a little squash at each turn ("hello").
ActionSample _wave(double t, FacePose f) {
  final s = math.sin(4 * math.pi * t / 1.4);
  final x = _Xf()
    ..rot = -0.06 * s
    ..squash(0.03 * s * s);
  return x.build(face: f.copyWith(smile: 1, open: 0.25, lidTop: 0));
}

/// Exhale: squash down, then a long overshooting stretch-release.
ActionSample _relief(double t, FacePose f) {
  final dev = t < 0.5
      ? _smooth(t / 0.5)
      : _spring(t - 0.5, 1.4, 5.0) * (1 - _ramp(t, 1.8, 2.2));
  final x = _Xf()..squash(0.1 * dev, 0.6);
  return x.build(
    face: f.copyWith(
      lidTop: 0.45,
      smile: 0.7,
      open: 0.25 * _bell((t - 0.45) / 0.8),
    ),
  );
}

/// Squeeze-in held with a gentle rock, blushing, hearts; springy release.
ActionSample _hug(double t, FacePose f) {
  final k = t < 0.4
      ? _smooth(t / 0.4)
      : t < 1.2
      ? 1.0
      : _spring(t - 1.2, 6, 12) * (1 - _ramp(t, 1.6, 1.8));
  final x = _Xf()
    ..sx = 1 - 0.08 * k
    ..sy = 1 + 0.04 * k
    ..rot = t >= 0.4 && t < 1.2
        ? 0.03 * math.sin(2 * math.pi * (t - 0.4) / 0.8)
        : 0;
  return x.build(
    face: f.copyWith(blush: 1, lidBottom: 0.5, smile: 0.6),
    hearts: _ramp(t, 0.25, 0.45) * (1 - _ramp(t, 1.2, 1.5)),
  );
}

/// Two quick bobs: squash, pop up 20 px, repeat.
ActionSample _nodYes(double t, FacePose f) {
  final x = _Xf()
    ..squash(0.03 * (_bell(t / 0.22) + _bell((t - 0.4) / 0.22)), 0.6)
    ..ty = -20 * (_bell((t - 0.12) / 0.3) + _bell((t - 0.52) / 0.3));
  return x.build(
    face: f.copyWith(lidBottom: 0.35, smile: math.max(f.smile, 0.8)),
  );
}

/// "Hmm": looks up (pupils up-left via the controller), slight tilt.
ActionSample _think(double t, FacePose f) {
  final env = _ramp(t, 0, 0.3) * (1 - _ramp(t, 1.2, 1.5));
  final x = _Xf()
    ..squash(-0.015 * env, 0.5)
    ..rot = -0.03 * env;
  return x.build(face: f.copyWith(gazeY: -0.8, smile: 0.2, mouthWidth: 0.6));
}
