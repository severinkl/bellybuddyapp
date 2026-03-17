import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../services/haptic_service.dart';

/// Wraps child content with edge-triggered horizontal swipe navigation.
/// Swipes must start from within [edgeThreshold] pixels of the screen edge.
class SwipeablePages extends StatefulWidget {
  final Widget child;
  final int currentIndex;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  const SwipeablePages({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.pageCount,
    required this.onPageChanged,
  });

  @override
  State<SwipeablePages> createState() => _SwipeablePagesState();
}

class _SwipeablePagesState extends State<SwipeablePages> {
  static const _edgeThreshold = 30.0;
  static const _swipeThreshold = 80.0;
  static const _boundaryResistance = 0.3;

  double _translateX = 0;
  double? _startX;
  double? _startY;
  bool? _isHorizontal;
  bool _isAnimating = false;

  void _onPanStart(DragStartDetails details) {
    final x = details.localPosition.dx;
    final width = context.size?.width ?? MediaQuery.of(context).size.width;

    final fromLeft = x < _edgeThreshold && widget.currentIndex > 0;
    final fromRight =
        x > width - _edgeThreshold &&
        widget.currentIndex < widget.pageCount - 1;

    if (fromLeft || fromRight) {
      _startX = details.localPosition.dx;
      _startY = details.localPosition.dy;
      _isHorizontal = null;
      _isAnimating = false;
    } else {
      _startX = null;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_startX == null || _startY == null) return;

    final dx = details.localPosition.dx - _startX!;
    final dy = details.localPosition.dy - _startY!;

    // Determine direction on first significant movement
    if (_isHorizontal == null && (dx.abs() > 10 || dy.abs() > 10)) {
      _isHorizontal = dx.abs() > dy.abs();
    }

    if (_isHorizontal != true) return;

    // Apply resistance at boundaries
    double constrained = dx;
    if ((dx > 0 && widget.currentIndex == 0) ||
        (dx < 0 && widget.currentIndex == widget.pageCount - 1)) {
      constrained = dx * _boundaryResistance;
    }

    setState(() => _translateX = constrained);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_startX == null || _isHorizontal != true) {
      _startX = null;
      _startY = null;
      _isHorizontal = null;
      return;
    }

    setState(() => _isAnimating = true);

    if (_translateX.abs() > _swipeThreshold) {
      if (_translateX > 0 && widget.currentIndex > 0) {
        HapticService.light();
        widget.onPageChanged(widget.currentIndex - 1);
      } else if (_translateX < 0 &&
          widget.currentIndex < widget.pageCount - 1) {
        HapticService.light();
        widget.onPageChanged(widget.currentIndex + 1);
      }
    }

    setState(() => _translateX = 0);
    _startX = null;
    _startY = null;
    _isHorizontal = null;

    Future.delayed(AppConstants.animMedium, () {
      if (mounted) setState(() => _isAnimating = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: _isAnimating ? AppConstants.animMedium : Duration.zero,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_translateX * 0.3, 0, 0),
            child: widget.child,
          ),
          // Left swipe indicator
          if (widget.currentIndex > 0 && _translateX > 20)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: (_translateX / _swipeThreshold).clamp(0.0, 1.0),
                  duration: AppConstants.animFast,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.card.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(color: AppTheme.shadow, blurRadius: 8),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '\u2039',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeTitleLG,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Right swipe indicator
          if (widget.currentIndex < widget.pageCount - 1 && _translateX < -20)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: (_translateX.abs() / _swipeThreshold).clamp(
                    0.0,
                    1.0,
                  ),
                  duration: AppConstants.animFast,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.card.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(color: AppTheme.shadow, blurRadius: 8),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '\u203A',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeTitleLG,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
