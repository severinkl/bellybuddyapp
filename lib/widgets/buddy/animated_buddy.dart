import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import 'buddy_actions.dart';
import 'buddy_controller.dart';
import 'buddy_geometry.dart';
import 'buddy_painter.dart';
import 'buddy_pose.dart';

/// The animated Buddy at any size. Ticks [controller] every frame while
/// visible (its ticker is muted inside `TickerMode(enabled: false)`), honours
/// `MediaQuery.disableAnimations`, and reacts to taps: on the body it pokes,
/// elsewhere the Buddy looks at the tap.
class AnimatedBuddy extends StatefulWidget {
  const AnimatedBuddy({
    super.key,
    required this.controller,
    this.name = 'Buddy',
    this.onPoke,
    this.interactive = true,
  });

  final BuddyController controller;

  /// Used in the semantics label (`"<name>, <Stimmung>"`).
  final String name;

  /// Called after a tap on the body started [BuddyAction.poke].
  final VoidCallback? onPoke;

  /// Whether taps poke / redirect the gaze.
  final bool interactive;

  /// Test seam: while false, newly mounted Buddies render their current
  /// frame without starting their ticker, so `pumpAndSettle` can settle on
  /// screens that show one (e.g. the dashboard). Set it in a test directory's
  /// `flutter_test_config.dart`; never change it in app code.
  @visibleForTesting
  static bool tickerEnabled = true;

  @override
  State<AnimatedBuddy> createState() => _AnimatedBuddyState();
}

class _AnimatedBuddyState extends State<AnimatedBuddy>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  late BuddyMood _mood;

  @override
  void initState() {
    super.initState();
    _mood = widget.controller.mood;
    _ticker = createTicker(_onTick);
    if (AnimatedBuddy.tickerEnabled) _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.reducedMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(AnimatedBuddy oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      widget.controller.reducedMotion = MediaQuery.disableAnimationsOf(context);
      _mood = widget.controller.mood;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final c = widget.controller..tick(dt);
    // Only the semantics label depends on build; rebuild on mood changes.
    if (c.mood != _mood) setState(() => _mood = c.mood);
  }

  void _poke() {
    widget.controller.play(BuddyAction.poke);
    widget.onPoke?.call();
  }

  void _onTapUp(Size size, TapUpDetails d) {
    final p = BuddyLayout(size).toImage(d.localPosition);
    if (widget.controller.hitTest(p)) {
      _poke();
    } else {
      widget.controller.lookAt(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${widget.name}, ${buddyMoodLabel(_mood)}',
      image: true,
      onTap: widget.interactive ? _poke : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = _sizeFor(constraints);
          if (size.isEmpty) return const SizedBox.shrink();
          Widget child = RepaintBoundary(
            child: CustomPaint(
              size: size,
              willChange: true,
              painter: BuddyPainter(widget.controller),
            ),
          );
          if (widget.interactive) {
            child = GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTapUp: (d) => _onTapUp(size, d),
              child: child,
            );
          }
          return child;
        },
      ),
    );
  }

  /// Fills bounded constraints; with one unbounded axis, keeps the Buddy's
  /// stage aspect ratio.
  static Size _sizeFor(BoxConstraints c) {
    if (c.hasBoundedWidth && c.hasBoundedHeight) return c.biggest;
    if (c.hasBoundedWidth) {
      return c.constrain(Size(c.maxWidth, c.maxWidth / kBuddyStageAspect));
    }
    if (c.hasBoundedHeight) {
      return c.constrain(Size(c.maxHeight * kBuddyStageAspect, c.maxHeight));
    }
    return c.smallest;
  }
}
