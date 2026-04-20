import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/constants.dart';
import '../../../services/haptic_service.dart';

/// Horizontal-swipe day-switcher for the Diary body.
///
/// Wraps a [child] and invokes [onPrevious] / [onNext] when the user drags
/// horizontally past [_swipeThreshold]. Uses `HitTestBehavior.translucent`
/// so inner widgets (e.g. `Dismissible` on diary entry cards) still win
/// the gesture arena on their own hit rect.
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

class _DiaryDaySwiperState extends State<DiaryDaySwiper>
    with SingleTickerProviderStateMixin {
  static const double _swipeThreshold = 80.0;
  static const double _boundaryResistance = 0.3;
  static const double _directionDecisionThreshold = 10.0;

  double _dragDx = 0;
  double? _startX;
  double? _startY;
  bool? _isHorizontal;
  bool _isAnimating = false;
  Timer? _settleTimer;

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _startX = details.localPosition.dx;
    _startY = details.localPosition.dy;
    _isHorizontal = null;
    _isAnimating = false;
    _dragDx = 0;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_startX == null || _startY == null) return;

    final dx = details.localPosition.dx - _startX!;
    final dy = details.localPosition.dy - _startY!;

    if (_isHorizontal == null &&
        (dx.abs() > _directionDecisionThreshold ||
            dy.abs() > _directionDecisionThreshold)) {
      _isHorizontal = dx.abs() > dy.abs();
    }

    if (_isHorizontal != true) return;

    // Boundary resistance: when dragging toward a bound we can't cross,
    // dampen the translation so the content rubber-bands instead of
    // moving freely.
    double constrained = dx;
    final hitsBackBound = dx > 0 && !widget.canSwipeBack;
    final hitsForwardBound = dx < 0 && !widget.canSwipeForward;
    if (hitsBackBound || hitsForwardBound) {
      constrained = dx * _boundaryResistance;
    }

    setState(() => _dragDx = constrained);
  }

  void _onPanEnd(DragEndDetails details) {
    final wasHorizontal = _isHorizontal == true;
    _startX = null;
    _startY = null;
    _isHorizontal = null;

    if (!wasHorizontal) {
      setState(() => _dragDx = 0);
      return;
    }

    setState(() => _isAnimating = true);

    if (_dragDx <= -_swipeThreshold && widget.canSwipeForward) {
      HapticService.light();
      widget.onNext();
    } else if (_dragDx >= _swipeThreshold && widget.canSwipeBack) {
      HapticService.light();
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
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedContainer(
        duration: _isAnimating ? AppConstants.animNormal : Duration.zero,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(_dragDx, 0, 0),
        child: widget.child,
      ),
    );
  }
}
