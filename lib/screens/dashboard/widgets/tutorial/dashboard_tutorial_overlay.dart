import 'package:flutter/material.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../utils/logger.dart';
import 'connector_line.dart';
import 'spotlight_painter.dart';
import 'tooltip_bubble.dart';
import 'tutorial_step.dart';

/// Full-screen overlay widget driving the 10-step dashboard tour.
///
/// Displayed by inserting it into the root [Overlay] (see
/// `show_dashboard_tutorial.dart`). Tapping anywhere advances a step.
/// Tapping the "Überspringen" link in the top-right finishes immediately.
/// Calls [onFinish] exactly once when the last step is advanced past OR
/// when the user skips.
class DashboardTutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onFinish;

  const DashboardTutorialOverlay({
    super.key,
    required this.steps,
    required this.onFinish,
  });

  @override
  State<DashboardTutorialOverlay> createState() =>
      _DashboardTutorialOverlayState();
}

class _DashboardTutorialOverlayState extends State<DashboardTutorialOverlay>
    with SingleTickerProviderStateMixin {
  static const _log = AppLogger('TutorialOverlay');

  int _index = 0;
  Rect? _targetRect;
  bool _finished = false;

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: AppConstants.animFast,
  )..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _measure() {
    final step = widget.steps[_index];
    final ctx = step.targetKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) {
      // Target not mounted / attached — skip it so we don't get stuck. Log
      // so a broken key surfaces during development instead of silently
      // disappearing from the tour.
      _log.warn(
        'step $_index (${step.targetKey.toString()}) skipped: no attached RenderBox',
      );
      _advance();
      return;
    }
    final topLeft = box.localToGlobal(Offset.zero);
    setState(() {
      _targetRect = topLeft & box.size;
    });
  }

  void _advance() {
    if (_finished) return;
    if (_index >= widget.steps.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _index += 1;
      _targetRect = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    await _fade.reverse();
    if (!mounted) return;
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final rect = _targetRect;
    final safe = MediaQuery.of(context).padding;

    return FadeTransition(
      opacity: _fade,
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            return Stack(
              children: [
                // Advance-on-tap layer + dim + cutout painter
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _advance,
                    child: CustomPaint(
                      painter: rect == null
                          ? null
                          : SpotlightPainter(
                              targetRect: rect.inflate(AppConstants.spacingXs),
                              targetRadius: step.targetRadius,
                            ),
                    ),
                  ),
                ),
                // Tooltip bubble + connector
                if (rect != null)
                  ..._buildBubbleAndConnector(
                    step: step,
                    targetRect: rect,
                    screenSize: screenSize,
                    safe: safe,
                  ),
                // "Überspringen" link (must sit above the advance layer)
                Positioned(
                  top: safe.top + AppConstants.spacingSm,
                  left: AppConstants.spacingMd,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _finish,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingMd,
                        vertical: AppConstants.spacingMd,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.background.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusRound,
                        ),
                      ),
                      child: const Text(
                        'Überspringen',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeBody,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foreground,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildBubbleAndConnector({
    required TutorialStep step,
    required Rect targetRect,
    required Size screenSize,
    required EdgeInsets safe,
  }) {
    const horizontalMargin = AppConstants.spacingLg;
    final maxBubbleWidth = screenSize.width - (horizontalMargin * 2);

    // Decide actual anchor based on available space.
    final spaceAbove = targetRect.top - safe.top;
    final spaceBelow = screenSize.height - safe.bottom - targetRect.bottom;
    TooltipAnchor anchor = step.preferredAnchor;
    if (anchor == TooltipAnchor.above && spaceAbove < _minAnchorSpace) {
      anchor = TooltipAnchor.below;
    } else if (anchor == TooltipAnchor.below && spaceBelow < _minAnchorSpace) {
      anchor = TooltipAnchor.above;
    }

    const gap = AppConstants.spacingLg; // spacing between target and bubble
    final bubble = TooltipBubble(
      richText: step.richText,
      maxWidth: maxBubbleWidth,
    );

    // Horizontal position: center on target, clamped to screen margins.
    final bubbleWidth = maxBubbleWidth; // upper bound; actual may be smaller
    final bubbleCenterX = targetRect.center.dx.clamp(
      horizontalMargin + bubbleWidth / 2,
      screenSize.width - horizontalMargin - bubbleWidth / 2,
    );

    // Vertical position of bubble's top edge:
    final bubbleTop = anchor == TooltipAnchor.above
        ? (targetRect.top - gap - _estimatedBubbleHeight)
        : (targetRect.bottom + gap);

    final bubbleRectApprox = Rect.fromLTWH(
      bubbleCenterX - bubbleWidth / 2,
      bubbleTop,
      bubbleWidth,
      _estimatedBubbleHeight,
    );

    // Connector endpoints
    final targetAnchor = Offset(
      targetRect.center.dx,
      anchor == TooltipAnchor.above ? targetRect.top : targetRect.bottom,
    );
    final bubbleAnchor = Offset(
      bubbleRectApprox.center.dx,
      anchor == TooltipAnchor.above
          ? bubbleRectApprox.bottom
          : bubbleRectApprox.top,
    );

    return [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: ConnectorLine(
              bubbleAnchor: bubbleAnchor,
              targetAnchor: targetAnchor,
            ),
          ),
        ),
      ),
      Positioned(
        left: bubbleRectApprox.left,
        top: bubbleRectApprox.top,
        width: bubbleRectApprox.width,
        child: IgnorePointer(child: bubble),
      ),
    ];
  }

  // Rough upper bound — used only for connector-line endpoint math. The
  // actual bubble sizes itself based on its content; the connector just
  // needs a reasonable approximation.
  static const double _estimatedBubbleHeight = 140;

  // Minimum vertical space required on the preferred side before we flip
  // the bubble anchor to the opposite side of the target.
  static const double _minAnchorSpace = 140;
}
