import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/constants.dart';

/// Horizontal-swipe day-switcher for the Diary body.
///
/// Wraps a [child] and invokes [onPrevious] / [onNext] when the user drags
/// horizontally past [_swipeThreshold]. Uses `HitTestBehavior.translucent`
/// so inner widgets (e.g. `Dismissible` on diary entry cards) still win
/// the gesture arena on their own hit rect.
///
/// Uses `onHorizontalDrag*` (backed by `HorizontalDragGestureRecognizer`),
/// which matches what `Dismissible` on entry cards uses, so the gesture-
/// arena resolution is symmetric between the two.
class DiaryDaySwiper extends StatefulWidget {
  final Widget child;
  final bool canSwipeBack;
  final bool canSwipeForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const DiaryDaySwiper({
    super.key,
    required this.child,
    required this.canSwipeBack,
    required this.canSwipeForward,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  State<DiaryDaySwiper> createState() => _DiaryDaySwiperState();
}

class _DiaryDaySwiperState extends State<DiaryDaySwiper> {
  static const double _swipeThreshold = 80.0;
  static const double _boundaryResistance = 0.3;

  double _dragDx = 0;
  bool _isAnimating = false;
  Timer? _settleTimer;

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragDx = 0;
    _isAnimating = false;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    var nextDx = _dragDx + delta;

    // Rubber-band when dragging past an unreachable bound.
    final hitsBackBound = nextDx > 0 && !widget.canSwipeBack;
    final hitsForwardBound = nextDx < 0 && !widget.canSwipeForward;
    if (hitsBackBound || hitsForwardBound) {
      // Apply resistance incrementally so it feels smooth.
      nextDx = _dragDx + delta * _boundaryResistance;
    }
    setState(() => _dragDx = nextDx);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    setState(() => _isAnimating = true);

    if (_dragDx <= -_swipeThreshold && widget.canSwipeForward) {
      widget.onNext();
    } else if (_dragDx >= _swipeThreshold && widget.canSwipeBack) {
      widget.onPrevious();
    }
    setState(() => _dragDx = 0);

    // Reset the animating flag after the translate animation would
    // finish. Purely cosmetic: prevents a second swipe from compounding
    // the translate before the first has settled.
    _settleTimer?.cancel();
    _settleTimer = Timer(AppConstants.animNormal, () {
      if (mounted) setState(() => _isAnimating = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: AnimatedContainer(
        duration: _isAnimating ? AppConstants.animNormal : Duration.zero,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(_dragDx, 0, 0),
        child: widget.child,
      ),
    );
  }
}
