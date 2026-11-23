/// Time, mood blending, one-shot actions, gaze, blink and the speech-bubble
/// text of the animated Buddy. Widgets only render [BuddyController.frame].
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;
import 'dart:ui' as ui show Image;

import 'package:flutter/foundation.dart';

import 'buddy_actions.dart';
import 'buddy_geometry.dart';
import 'buddy_pose.dart';

/// Read-only per-frame snapshot for the painter. Transforms are in Buddy
/// image space (`tx`/`ty` in image px, `rot` in radians about the bottom
/// centre).
///
/// Painters must take motion from the frame's own fields ([rot], [breath],
/// [sway], [bulgeAmt], [foodPos]), which already honour reduced motion, and
/// not from the matching [face] fields (`face.lean`, `face.breath`, …).
/// [bulgePoint] may be non-null while [bulgeAmt] is 0; draw no bulge then.
@immutable
class BuddyFrame {
  const BuddyFrame({
    required this.t,
    required this.face,
    required this.blink,
    required this.gaze,
    required this.tx,
    required this.ty,
    required this.sx,
    required this.sy,
    required this.rot,
    required this.breath,
    required this.sway,
    required this.bulgePoint,
    required this.bulgeAmt,
    required this.bulgeIsWater,
    required this.foodPos,
    required this.foodScale,
    required this.food,
    required this.sparkleP,
    required this.hearts,
  });

  /// Seconds since the controller was created (sum of clamped ticks).
  final double t;

  /// Blended expression (mood pose with the action override on top).
  final FacePose face;

  /// Blink closure 0..1 on top of `face.lidTop`.
  final double blink;

  /// Normalised pupil direction, `|gaze| <= 1`.
  final Offset gaze;

  /// Body transform: idle motion composed with the action's transform.
  /// `rot` includes the static `face.lean`.
  final double tx, ty, sx, sy, rot;

  /// Signed breathing deformation (amplitude × sin of the breath phase).
  final double breath;

  /// Jelly-sway wave amplitude in image px.
  final double sway;

  final Offset? bulgePoint;
  final double bulgeAmt;
  final bool bulgeIsWater;
  final Offset? foodPos;
  final double foodScale;

  /// Food image passed to `play(BuddyAction.eat, food: …)`, while it runs.
  final ui.Image? food;

  /// Sparkle burst progress 0..1, or -1 when no sparkles are shown.
  final double sparkleP;

  /// Action floating-hearts intensity (the painter also uses `face.hearts`).
  final double hearts;
}

/// The speech bubble: its text (null when nothing to say) and the id of the
/// [BuddyController.say] that set it.
typedef BuddyBubble = ({String? text, int id});

/// Drives the Buddy: call [tick] once per frame (e.g. from a `Ticker`).
///
/// Setters and commands ([mood], [play], [lookAt], [say], [reducedMotion])
/// never notify by themselves, so they are safe to call during build; their
/// effect shows on the next [tick], which always notifies.
class BuddyController extends ChangeNotifier {
  BuddyController({this.mood = BuddyMood.happy, int seed = 42})
    : _pose = FacePose.forMood(mood),
      _rnd = math.Random(seed) {
    _step(0);
  }

  // Blend rates (1/s) and timings ported from the spike `BuddyRig.update`.
  static const double _moodRate = 5;
  static const double _overrideInRate = 16;
  static const double _overrideOutRate = 10;
  static const double _gazeRate = 14;
  static const double _blinkDuration = 0.2;
  static const double _lidsClosed = 0.9;

  /// wakeUp's two blinks (seconds into the action). The action's own lidTop
  /// pulses (1.0–1.3 s) are too short to survive the 16/s override blend, so
  /// real blinks run on top of them, back to back (a blink lasts 0.2 s).
  static const List<double> _wakeUpBlinks = [1.0, 1.2];

  /// Hungry tummy rumble: a burst every [_rumblePeriod] s.
  static const double _rumblePeriod = 3;
  static const double _rumbleBurst = 0.6;
  static const double _rumbleRot = 0.02;
  static const double _rumbleRotFreq = 45;
  static const double _rumbleSway = 10;

  /// A [play] that interrupts an action fades the old transform out over
  /// this many seconds (smoothstep) instead of snapping to the new start.
  static const double _carryFade = 0.3;

  /// `think` looks up-left regardless of other gaze targets.
  static const Offset _thinkGaze = Offset(-0.7, -0.8);

  /// Reduced-motion breathing amplitude factor.
  static const double _reducedBreath = 0.3;

  final math.Random _rnd;

  /// Target mood; the face blends toward it at 5/s.
  BuddyMood mood;

  /// Calm mode for `MediaQuery.disableAnimations`: no sway, hop, shake,
  /// rumble, jump or bulge travel; damped breathing. Face cross-fades,
  /// blinks, gaze and sparkles stay.
  bool reducedMotion = false;

  double _t = 0;
  FacePose _pose;
  FacePose? _ovr;
  double _ovrW = 0;

  BuddyAction? _action;
  double _actionStart = 0;
  ui.Image? _food;

  /// The action's transform on the last step (incl. any carry), and the
  /// part of it carried over when [play] interrupts a running action.
  _Delta _lastAct = _Delta.zero, _carry = _Delta.zero;
  double _carryStart = 0;

  double _breathPhase = 0;
  double _nextBlink = 1.5, _blinkStart = -10, _blink = 0;
  Offset _gaze = const Offset(-0.6, -0.3);
  Offset _gazeTarget = const Offset(-0.6, -0.3);
  double _nextGlance = 1.0;
  Offset? _lookAt;
  double _lookUntil = 0;

  String? _bubble;
  int _bubbleId = 0;
  double _bubbleUntil = 0;
  late final _BubbleNotifier _bubbleNotifier = _BubbleNotifier(this);

  late BuddyFrame _frame;
  BuddyFrame get frame => _frame;

  /// The running one-shot action, or null once it has finished.
  BuddyAction? get currentAction => _action;

  /// Starts [action] from its beginning, replacing any running action; the
  /// interrupted action's body transform fades out instead of snapping.
  ///
  /// [food] is shown as the falling food of [BuddyAction.eat] and ignored for
  /// other actions. The caller owns and disposes the image and must keep it
  /// alive while the action runs.
  void play(BuddyAction action, {ui.Image? food}) {
    _action = action;
    _actionStart = _t;
    _food = action == BuddyAction.eat ? food : null;
    _carry = _lastAct;
    _carryStart = _t;
  }

  /// Looks at [imagePoint] (Buddy image coords) for [hold].
  void lookAt(
    Offset imagePoint, {
    Duration hold = const Duration(milliseconds: 1800),
  }) {
    _lookAt = imagePoint;
    _lookUntil = _t + _secs(hold);
  }

  /// Shows [text] in the speech bubble for [duration]; a null [duration]
  /// keeps it up until the next [say].
  void say(
    String text, {
    Duration? duration = const Duration(milliseconds: 2800),
  }) {
    _bubble = text;
    _bubbleId++;
    _bubbleUntil = duration == null ? double.infinity : _t + _secs(duration);
  }

  /// Current speech-bubble text; null when nothing to say.
  String? get bubble => _bubble;

  /// Increments with every [say], for `AnimatedSwitcher` keys.
  int get bubbleId => _bubbleId;

  /// The current [bubble] and [bubbleId]. Notifies only on the [tick] after
  /// they changed (a [say] or the bubble expiring), not every frame.
  ValueListenable<BuddyBubble> get bubbleListenable => _bubbleNotifier;

  /// Whether [imagePoint] (Buddy image coords) is on the Buddy.
  bool hitTest(Offset imagePoint) => BuddyShapes.hitPath.contains(imagePoint);

  /// Advances by [dt] seconds (clamped to `[0, 0.05]`) and notifies.
  void tick(double dt) {
    final d = dt.isNaN ? 0.0 : dt.clamp(0.0, 0.05);
    _t += d;
    _step(d);
    _bubbleNotifier.sync();
    notifyListeners();
  }

  static double _secs(Duration d) => d.inMicroseconds / 1e6;

  /// Smoothstep of [x] clamped to 0..1.
  static double _smooth(double x) {
    final c = x.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  @override
  void dispose() {
    _food = null;
    _bubbleNotifier.dispose();
    super.dispose();
  }

  /// 1 - e^(-rate·dt): frame-rate independent exponential approach factor.
  static double _approach(double rate, double dt) => 1 - math.exp(-dt * rate);

  void _step(double dt) {
    final t = _t;
    _pose = FacePose.lerp(
      _pose,
      FacePose.forMood(mood),
      _approach(_moodRate, dt),
    );

    // --- One-shot action.
    var s = const ActionSample.neutral();
    final action = _action;
    if (action != null) {
      final ta = t - _actionStart;
      if (ta >= _secs(buddyActionDuration(action))) {
        _action = null;
        _food = null;
      } else {
        s = sampleAction(action, ta, _pose);
        if (action == BuddyAction.wakeUp) {
          for (final at in _wakeUpBlinks) {
            if (ta - dt < at && ta >= at) _blinkStart = t;
          }
        }
      }
    }

    // --- Blend the action's face override in/out over the mood pose.
    final want = s.face;
    if (want != null) {
      final kIn = _approach(_overrideInRate, dt);
      // A fully faded override is stale; start the new one fresh so the
      // blend-in does not pass through the previous action's face.
      final ovr = _ovr;
      _ovr = ovr == null || _ovrW < 0.02 ? want : FacePose.lerp(ovr, want, kIn);
      _ovrW += (1 - _ovrW) * kIn;
    } else {
      _ovrW -= _ovrW * _approach(_overrideOutRate, dt);
    }
    final ovr = _ovr;
    final face = ovr == null ? _pose : FacePose.lerp(_pose, ovr, _ovrW);

    // --- Idle motion.
    var tx = 0.0, ty = 0.0, sx = 1.0, sy = 1.0, rot = face.lean;
    var sway = face.sway;

    // Breathing (phase integrated so rate changes don't jump).
    _breathPhase =
        (_breathPhase + dt * 2 * math.pi * face.breathRate) % (2 * math.pi);
    final breath = face.breath * math.sin(_breathPhase);
    sy *= 1 + breath * 0.35;

    // Nervous jitter.
    if (face.shake > 0.01) {
      tx += face.shake * 7 * math.sin(t * 53);
      rot += face.shake * 0.01 * math.sin(t * 37);
    }

    // Energetic idle hops.
    if (face.hop > 0.01) {
      final h = math.sin((t * 1.3) % 1.0 * math.pi);
      ty -= face.hop * 90 * h;
      final sq = face.hop * 0.07 * math.pow(1 - h, 4);
      sy *= 1 - sq;
      sx *= 1 + sq * 0.7;
    }

    // Hungry tummy rumble: fast small wiggle + sway swell, in bursts.
    if (face.rumble > 0.01) {
      final p = (t % _rumblePeriod) / _rumbleBurst;
      if (p < 1) {
        final sn = math.sin(math.pi * p);
        final env = sn * sn;
        rot += face.rumble * _rumbleRot * env * math.sin(t * _rumbleRotFreq);
        sway += face.rumble * _rumbleSway * env;
      }
    }

    final fade = (t - _carryStart) / _carryFade;
    final act =
        _Delta(s.tx, s.ty, s.sx - 1, s.sy - 1, s.rot) +
        _carry * (1 - _smooth(fade));
    _lastAct = act;
    tx += act.tx;
    ty += act.ty;
    sx *= 1 + act.sx;
    sy *= 1 + act.sy;
    rot += act.rot;

    _updateGaze(dt, t, face, s);
    _updateBlink(t, face);

    if (_bubble != null && t >= _bubbleUntil) _bubble = null;

    final rm = reducedMotion;
    _frame = BuddyFrame(
      t: t,
      face: rm ? face.copyWith(sway: 0, hop: 0, shake: 0, rumble: 0) : face,
      blink: _blink,
      gaze: _gaze,
      tx: rm ? 0 : tx,
      ty: rm ? 0 : ty,
      sx: rm ? 1 : sx,
      sy: rm ? 1 : sy,
      rot: rm ? 0 : rot,
      breath: rm ? breath * _reducedBreath : breath,
      sway: rm ? 0 : sway,
      bulgePoint: s.bulgePoint,
      bulgeAmt: rm ? 0 : s.bulgeAmt,
      bulgeIsWater: s.bulgeIsWater,
      foodPos: rm ? null : s.foodPos,
      foodScale: s.foodScale,
      food: _food,
      sparkleP: s.sparkleP,
      hearts: s.hearts,
    );
  }

  /// Gaze priority: action target (think / bulge / food) > [lookAt] > idle
  /// wandering. Under reduced motion the food and bulge are not drawn, so
  /// the eyes don't follow them.
  void _updateGaze(double dt, double t, FacePose face, ActionSample s) {
    Offset? target;
    Offset? point;
    if (_action == BuddyAction.think) {
      target = _thinkGaze;
    } else if (!reducedMotion) {
      point = s.bulgePoint ?? s.foodPos;
    }
    if (target == null && point == null && _lookAt != null && t < _lookUntil) {
      point = _lookAt;
    }
    if (point != null) {
      final d = point - kBuddyEyeMid;
      target = d / (d.distance + 220) * 1.3;
    }
    if (target == null) {
      if (t > _nextGlance) {
        _gazeTarget = Offset(
          _rnd.nextDouble() * 1.6 - 0.8,
          _rnd.nextDouble() - 0.5,
        );
        _nextGlance = t + 1.2 + _rnd.nextDouble() * 2.8;
      }
      target = _gazeTarget * face.gazeWander + Offset(0, face.gazeY);
    }
    if (target.distance > 1) target = target / target.distance;
    _gaze = Offset.lerp(_gaze, target, _approach(_gazeRate, dt))!;
  }

  void _updateBlink(double t, FacePose face) {
    if (t >= _nextBlink) {
      // Closed lids (zen) don't blink; wakeUp scripts its own blinks.
      if (face.lidTop < _lidsClosed && _action != BuddyAction.wakeUp) {
        _blinkStart = t;
      }
      _nextBlink =
          t + (_rnd.nextDouble() < 0.2 ? 0.3 : 2 + _rnd.nextDouble() * 3.5);
    }
    final b = (t - _blinkStart) / _blinkDuration;
    _blink = (b < 0 || b > 1) ? 0 : (b < 0.4 ? b / 0.4 : 1 - (b - 0.4) / 0.6);
  }
}

/// [BuddyController.bubbleListenable]: always reads the controller's current
/// bubble, and notifies from [sync] when it differs from the last notified
/// one.
class _BubbleNotifier extends ChangeNotifier
    implements ValueListenable<BuddyBubble> {
  _BubbleNotifier(this._controller);

  final BuddyController _controller;
  BuddyBubble _notified = (text: null, id: 0);

  static BuddyBubble _read(BuddyController c) =>
      (text: c._bubble, id: c._bubbleId);

  @override
  BuddyBubble get value => _read(_controller);

  void sync() {
    final v = value;
    if (v == _notified) return;
    _notified = v;
    notifyListeners();
  }
}

/// Action transform as deltas from rest (`sx`/`sy` relative to 1).
class _Delta {
  const _Delta(this.tx, this.ty, this.sx, this.sy, this.rot);
  static const zero = _Delta(0, 0, 0, 0, 0);
  final double tx, ty, sx, sy, rot;

  _Delta operator +(_Delta o) =>
      _Delta(tx + o.tx, ty + o.ty, sx + o.sx, sy + o.sy, rot + o.rot);
  _Delta operator *(double k) =>
      _Delta(tx * k, ty * k, sx * k, sy * k, rot * k);
}
