import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../services/haptic_service.dart';
import 'mascot_image.dart';

class BbSuccessOverlay extends StatefulWidget {
  final String message;
  final String? subMessage;
  final VoidCallback onDismissed;
  final List<Widget>? actions;
  final Widget? bottomCallout;
  final String? mascotAsset;

  const BbSuccessOverlay({
    super.key,
    required this.message,
    required this.onDismissed,
    this.subMessage,
    this.actions,
    this.bottomCallout,
    this.mascotAsset,
  });

  @override
  State<BbSuccessOverlay> createState() => _BbSuccessOverlayState();
}

class _BbSuccessOverlayState extends State<BbSuccessOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  late final AnimationController _mascotController;
  late final Animation<double> _mascotScaleAnimation;

  late final AnimationController _textController;
  late final Animation<double> _textOpacityAnimation;
  late final Animation<Offset> _textSlideAnimation;

  @override
  void initState() {
    super.initState();
    HapticService.medium();

    // Container: fade only (0.3s)
    _fadeController = AnimationController(
      vsync: this,
      duration: AppConstants.animMedium,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Mascot: bounce-overshoot scale 0.8 → 1.05 → 1.0 (0.6s)
    _mascotController = AnimationController(
      vsync: this,
      duration: AppConstants.animSlower,
    );
    _mascotScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.8,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.05,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_mascotController);

    // Text: slide-up + fade (0.4s, staggered start)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5), // ~20px down
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    // Start animations in sequence
    _fadeController.forward();
    Future.delayed(AppConstants.pressScaleDuration, () {
      if (mounted) _mascotController.forward();
    });
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _textController.forward();
    });

    // Auto-dismiss only when no mascot and no actions (legacy behavior)
    final hasActions = widget.actions != null && widget.actions!.isNotEmpty;
    if (!hasActions && widget.mascotAsset == null) {
      Future.delayed(AppConstants.successOverlayDuration, () {
        if (mounted) widget.onDismissed();
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _mascotController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMascot = widget.mascotAsset != null;
    final bgColor = hasMascot
        ? AppTheme.primary.withValues(alpha: 0.95)
        : AppTheme.background.withValues(alpha: 0.95);
    final textColor = hasMascot
        ? AppTheme.primaryForeground
        : AppTheme.foreground;

    Widget content = AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return Opacity(opacity: _fadeAnimation.value, child: child);
      },
      child: Container(
        color: bgColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingXl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mascot or checkmark
                if (hasMascot)
                  AnimatedBuilder(
                    animation: _mascotController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _mascotScaleAnimation.value,
                        child: child,
                      );
                    },
                    child: MascotImage(
                      assetPath: widget.mascotAsset!,
                      width: 160,
                      height: 160,
                    ),
                  )
                else
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppTheme.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                AppConstants.gap24,

                // Message + sub-message with slide-up animation
                SlideTransition(
                  position: _textSlideAnimation,
                  child: FadeTransition(
                    opacity: _textOpacityAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.message,
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeHeadingLG,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (widget.subMessage != null) ...[
                          AppConstants.gap8,
                          Text(
                            widget.subMessage!,
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeSubtitle,
                              color: textColor.withValues(alpha: 0.8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Action buttons
                if (widget.actions != null && widget.actions!.isNotEmpty) ...[
                  AppConstants.gap24,
                  if (hasMascot)
                    _PillActionButton(children: widget.actions!)
                  else
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < widget.actions!.length; i++) ...[
                          if (i > 0) AppConstants.gap8,
                          widget.actions![i],
                        ],
                      ],
                    ),
                ],

                if (widget.bottomCallout != null) ...[
                  AppConstants.gap16,
                  widget.bottomCallout!,
                ],

                // Tap hint
                if (hasMascot) ...[
                  const SizedBox(height: AppConstants.spacingXxl),
                  FadeTransition(
                    opacity: _textOpacityAnimation,
                    child: Text(
                      'Tippen zum Fortfahren',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeBody,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (hasMascot) {
      content = GestureDetector(onTap: widget.onDismissed, child: content);
    }

    return Material(type: MaterialType.transparency, child: content);
  }
}

/// Pill-shaped action button container — absorbs taps to prevent dismiss.
/// Renders each child in its own pill, separated by [AppConstants.gap8].
class _PillActionButton extends StatelessWidget {
  final List<Widget> children;

  const _PillActionButton({required this.children});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // absorb tap to prevent dismiss
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) AppConstants.gap8,
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingLg,
                vertical: AppConstants.spacing12,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: AppTheme.fontSizeBody,
                  decoration: TextDecoration.none,
                ),
                child: children[i],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
