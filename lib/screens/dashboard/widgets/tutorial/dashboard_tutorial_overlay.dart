import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../utils/logger.dart';
import 'connector_line.dart';
import 'spotlight_painter.dart';
import 'tooltip_bubble.dart';
import 'tutorial_step.dart';

/// Full-screen overlay widget driving the dashboard tour.
///
/// Displayed by inserting it into the root [Overlay] (see
/// `show_dashboard_tutorial.dart`). Tapping anywhere advances a step.
/// Tapping the "Überspringen" link in the top-right finishes immediately.
/// Calls [onFinish] exactly once when the last step is advanced past OR
/// when the user skips.
class DashboardTutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onFinish;

  /// Key on the full-screen GestureDetector that advances the tour on tap.
  /// Exposed so tests can drive "advance" without relying on screen-space
  /// coordinates (which change with the Überspringen link's position).
  static const advanceKey = Key('tutorial_overlay_advance');

  /// Key on the „Überspringen" pill.
  static const skipKey = Key('tutorial_overlay_skip');

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

  /// The widest the „Überspringen" pill gets, as a share of the screen.
  static const _skipMaxWidth = 0.4;

  int _index = 0;
  Rect? _targetRect;
  bool _finished = false;

  /// The „Überspringen" pill, measured with each target: the bubble stays
  /// below it.
  final _skipBox = GlobalKey();
  double? _skipBottom;

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: AppConstants.animFast,
  )..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStep());
    WidgetsBinding.instance.addPostFrameCallback(_follow);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  /// Scrolls the current step's target into view when it sits in a
  /// scrollable and is not fully visible (e.g. the insight card below the
  /// Buddy hero on a small phone), then measures it.
  Future<void> _showStep() async {
    final index = _index;
    final ctx = widget.steps[index].targetKey.currentContext;
    final scrollable = ctx == null ? null : Scrollable.maybeOf(ctx);
    if (ctx != null && scrollable != null && !_fullyVisible(ctx, scrollable)) {
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: AppConstants.animFast,
      );
      // The scroll lands in a frame's animation phase; slivers only move in
      // its layout, so measure once that frame is done.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || _finished || index != _index) return;
    }
    _measure();
  }

  /// Whether [target] lies completely inside [scrollable]'s viewport.
  static bool _fullyVisible(BuildContext target, ScrollableState scrollable) {
    final box = target.findRenderObject();
    final viewport = scrollable.context.findRenderObject();
    if (box is! RenderBox ||
        viewport is! RenderBox ||
        !box.attached ||
        !viewport.attached) {
      return true; // nothing laid out to scroll to; _measure handles it
    }
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(viewport),
      Offset.zero & box.size,
    );
    final bounds = Offset.zero & viewport.size;
    return rect.left >= bounds.left &&
        rect.top >= bounds.top &&
        rect.right <= bounds.right &&
        rect.bottom <= bounds.bottom;
  }

  /// Where the current step's target is on screen right now; null while it
  /// is not mounted / attached, or hidden (no size).
  Rect? _targetOnScreen() {
    final ctx = widget.steps[_index].targetKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize || box.size.isEmpty) {
      return null;
    }
    // Transform-aware: MatrixUtils.transformRect respects any ancestor
    // transform (e.g. PressScaleWrapper's ScaleTransition around the
    // tracker cards). localToGlobal + size alone silently drops
    // non-translation transforms and occasionally returned a mis-sized
    // rect for the first step.
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }

  /// After every frame while the tour is up: the spotlight follows its
  /// target, which may still be moving when its step starts (on a cold
  /// start Home slides in from /loading while the tour begins). Runs only
  /// on frames that happen anyway; it never schedules one.
  void _follow(Duration _) {
    if (!mounted || _finished) return;
    // Null between steps, until _showStep has measured the next target
    // (after scrolling to it).
    if (_targetRect != null) {
      final rect = _targetOnScreen();
      if (rect != null && rect != _targetRect) {
        setState(() => _targetRect = rect);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback(_follow);
  }

  void _measure() {
    final step = widget.steps[_index];
    final rect = _targetOnScreen();
    if (rect == null) {
      // Target not mounted / attached, or hidden (e.g. the insight card
      // while its progress failed to load) — skip it so we don't get stuck
      // or point at nothing. Log so a broken key surfaces during
      // development instead of silently disappearing from the tour.
      _log.warn(
        'step $_index (${step.targetKey.toString()}) skipped: no visible RenderBox',
      );
      _advance();
      return;
    }
    final skip = _skipBox.currentContext?.findRenderObject() as RenderBox?;
    setState(() {
      _targetRect = rect;
      _skipBottom = skip == null || !skip.hasSize
          ? null
          : skip.localToGlobal(Offset(0, skip.size.height)).dy;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStep());
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
                    key: DashboardTutorialOverlay.advanceKey,
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
                    top: _skipBottom ?? safe.top,
                  ),
                // "Überspringen" link (must sit above the advance layer),
                // top right and at most [_skipMaxWidth] of the width: in the
                // band above Home's ring (his bubble is hidden meanwhile),
                // clear of the need bubbles the first step spotlights.
                Positioned(
                  top: safe.top + AppConstants.spacingSm,
                  right: AppConstants.spacingMd,
                  child: GestureDetector(
                    key: DashboardTutorialOverlay.skipKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: _finish,
                    child: Container(
                      key: _skipBox,
                      constraints: BoxConstraints(
                        minHeight: AppConstants.minTapTarget,
                        maxWidth: screenSize.width * _skipMaxWidth,
                      ),
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
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Überspringen',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeBody,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.foreground,
                          ),
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

  /// The step's bubble and its connector to [targetRect], the bubble below
  /// [top] (the „Überspringen" pill's bottom, which spans its width).
  List<Widget> _buildBubbleAndConnector({
    required TutorialStep step,
    required Rect targetRect,
    required Size screenSize,
    required EdgeInsets safe,
    required double top,
  }) {
    const horizontalMargin = AppConstants.spacingLg;
    final bubbleWidth = screenSize.width - (horizontalMargin * 2);

    // Decide actual anchor based on available space.
    final spaceAbove = targetRect.top - top;
    final spaceBelow = screenSize.height - safe.bottom - targetRect.bottom;
    TooltipAnchor anchor = step.preferredAnchor;
    if (anchor == TooltipAnchor.above && spaceAbove < _minAnchorSpace) {
      anchor = TooltipAnchor.below;
    } else if (anchor == TooltipAnchor.below && spaceBelow < _minAnchorSpace) {
      anchor = TooltipAnchor.above;
    }

    const gap = AppConstants.spacingLg; // spacing between target and bubble
    final above = anchor == TooltipAnchor.above;

    // Connector endpoints: the target's edge and the bubble's edge one gap
    // away, where _BubbleLayout puts it (unless it must move on screen).
    final targetAnchor = Offset(
      targetRect.center.dx,
      above ? targetRect.top : targetRect.bottom,
    );
    final bubbleAnchor = Offset(
      screenSize.width / 2,
      above ? targetRect.top - gap : targetRect.bottom + gap,
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
      Positioned.fill(
        child: IgnorePointer(
          child: CustomSingleChildLayout(
            delegate: _BubbleLayout(
              edge: bubbleAnchor.dy,
              above: above,
              width: bubbleWidth,
              minTop: top + AppConstants.spacingSm,
              maxBottom:
                  screenSize.height - safe.bottom - AppConstants.spacingSm,
            ),
            child: TooltipBubble(
              richText: step.richText,
              maxWidth: bubbleWidth,
            ),
          ),
        ),
      ),
    ];
  }

  // Minimum vertical space required on the preferred side before we flip
  // the bubble anchor to the opposite side of the target.
  static const double _minAnchorSpace = 140;
}

/// Places the tooltip bubble at its real height: horizontally centred, its
/// near edge at [edge] (its bottom when [above], else its top), then moved
/// back between [minTop] and [maxBottom] when it does not fit there (it may
/// then cover part of a tall target, but it is always readable).
class _BubbleLayout extends SingleChildLayoutDelegate {
  const _BubbleLayout({
    required this.edge,
    required this.above,
    required this.width,
    required this.minTop,
    required this.maxBottom,
  });

  final double edge;
  final bool above;
  final double width;
  final double minTop;
  final double maxBottom;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: constraints.maxHeight,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final top = above ? edge - childSize.height : edge;
    final maxTop = math.max(minTop, maxBottom - childSize.height);
    return Offset(
      (size.width - childSize.width) / 2,
      top.clamp(minTop, maxTop),
    );
  }

  @override
  bool shouldRelayout(_BubbleLayout old) =>
      old.edge != edge ||
      old.above != above ||
      old.width != width ||
      old.minTop != minTop ||
      old.maxBottom != maxBottom;
}
