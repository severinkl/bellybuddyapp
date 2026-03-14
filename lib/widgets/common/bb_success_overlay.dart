import 'dart:ui';

import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/haptic_service.dart';
import 'mascot_image.dart';

class BbSuccessOverlay extends StatefulWidget {
  final String message;
  final String? subMessage;
  final VoidCallback onDismissed;
  final Widget? action;
  final String? mascotAsset;

  const BbSuccessOverlay({
    super.key,
    required this.message,
    required this.onDismissed,
    this.subMessage,
    this.action,
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
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    // Mascot: bounce-overshoot scale 0.8 → 1.05 → 1.0 (0.6s)
    _mascotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _mascotScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.8, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_mascotController);

    // Text: slide-up + fade (0.4s, staggered start)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5), // ~20px down
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    // Start animations in sequence
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _mascotController.forward();
    });
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _textController.forward();
    });

    // Auto-dismiss only when no mascot and no action (legacy behavior)
    if (widget.action == null && widget.mascotAsset == null) {
      Future.delayed(const Duration(milliseconds: 1500), () {
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
    final textColor =
        hasMascot ? AppTheme.primaryForeground : AppTheme.foreground;

    Widget content = AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: child,
        );
      },
      child: Container(
        color: bgColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
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
                const SizedBox(height: 24),

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
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (widget.subMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.subMessage!,
                            style: TextStyle(
                              fontSize: 16,
                              color: textColor.withValues(alpha: 0.8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Action button
                if (widget.action != null) ...[
                  const SizedBox(height: 24),
                  if (hasMascot)
                    _GlassmorphicActionButton(
                      child: widget.action!,
                    )
                  else
                    widget.action!,
                ],

                // Tap hint
                if (hasMascot) ...[
                  const SizedBox(height: 48),
                  FadeTransition(
                    opacity: _textOpacityAnimation,
                    child: Text(
                      'Tippen zum Fortfahren',
                      style: TextStyle(
                        fontSize: 14,
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
      content = GestureDetector(
        onTap: widget.onDismissed,
        child: content,
      );
    }

    return content;
  }
}

/// Glassmorphic pill button wrapper — absorbs taps to prevent dismiss.
class _GlassmorphicActionButton extends StatelessWidget {
  final Widget child;

  const _GlassmorphicActionButton({required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // absorb tap to prevent dismiss
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                color: AppTheme.primaryForeground,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
              child: IconTheme.merge(
                data: const IconThemeData(color: AppTheme.primaryForeground),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
