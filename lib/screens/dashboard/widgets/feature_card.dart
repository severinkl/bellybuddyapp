import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/press_scale_wrapper.dart';

const _kPulseDuration = Duration(milliseconds: 700);
const _kPulseScaleMax = 1.08;
const _kPulseHaloSpread = 6.0;
const _kPulseHaloOpacity = 0.55;

class FeatureCard extends StatefulWidget {
  final String imageAsset;
  final String label;
  final IconData icon;
  final Color iconColor;
  final int badgeCount;
  final bool hasNew;
  final VoidCallback onTap;

  const FeatureCard({
    super.key,
    required this.imageAsset,
    required this.label,
    required this.icon,
    required this.iconColor,
    this.badgeCount = 0,
    this.hasNew = false,
    required this.onTap,
  }) : assert(
         !hasNew || badgeCount == 0,
         'hasNew and badgeCount > 0 are mutually exclusive — the badge would '
         'silently render "ungelesen" and drop the count.',
       );

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard>
    with SingleTickerProviderStateMixin {
  static const _borderWidth = 3.0;

  late final AnimationController _controller;
  bool? _isAnimating;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _kPulseDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant FeatureCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  /// Starts or stops the pulse based on [widget.hasNew] and the current
  /// `MediaQuery.disableAnimations` flag. Guarded by [_isAnimating] so a
  /// rebuild with unchanged effective state is a no-op.
  void _syncAnimation() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final shouldAnimate = widget.hasNew && !reduceMotion;
    if (shouldAnimate == _isAnimating) return;
    _isAnimating = shouldAnimate;
    if (shouldAnimate) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _showBorder => widget.hasNew || widget.badgeCount > 0;

  @override
  Widget build(BuildContext context) {
    final shouldAnimate = _isAnimating ?? false;
    return PressScaleWrapper(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: _showBorder
              ? Border.all(color: AppTheme.primary, width: _borderWidth)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            _showBorder
                ? AppConstants.radiusLg - _borderWidth
                : AppConstants.radiusLg,
          ),
          child: SizedBox(
            height: AppConstants.featureCardHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(widget.imageAsset, fit: BoxFit.cover),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                if (widget.hasNew || widget.badgeCount > 0)
                  Positioned(
                    top: AppConstants.spacingSm,
                    right: AppConstants.spacingSm,
                    child: _Badge(
                      text: widget.hasNew
                          ? 'ungelesen'
                          : '${widget.badgeCount}',
                      controller: shouldAnimate ? _controller : null,
                    ),
                  ),
                Positioned(
                  bottom: AppConstants.spacing10,
                  left: AppConstants.spacing10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacing10,
                      vertical: AppConstants.spacing6,
                    ),
                    decoration: BoxDecoration(
                      color: _showBorder
                          ? AppTheme.primary
                          : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusRound,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.icon,
                          size: AppConstants.iconSizeXs,
                          color: widget.iconColor,
                        ),
                        const SizedBox(width: AppConstants.spacingXs),
                        Text(
                          widget.label,
                          style: const TextStyle(
                            fontSize: AppTheme.fontSizeBodyLG,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.foreground,
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacing2),
                        const Icon(
                          Icons.chevron_right,
                          size: AppConstants.spacing14,
                          color: AppTheme.mutedForeground,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.controller});

  final String text;
  final AnimationController? controller;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeCaption,
          fontWeight: FontWeight.w600,
          color: AppTheme.foreground,
        ),
      ),
    );
    if (controller == null) return badge;
    return AnimatedBuilder(
      animation: controller!,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(controller!.value);
        return Transform.scale(
          scale: 1.0 + (_kPulseScaleMax - 1.0) * t,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(
                    alpha: _kPulseHaloOpacity * (1 - t),
                  ),
                  blurRadius: 0,
                  spreadRadius: _kPulseHaloSpread * t,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: badge,
    );
  }
}
