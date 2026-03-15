import 'package:flutter/material.dart';
import '../../config/constants.dart';
import '../../services/haptic_service.dart';
import 'bb_slider.dart';
import 'mascot_image.dart';

class MoodSliderRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final String? leftLabel;
  final String rightLabel;
  final String leftMascot;
  final String rightMascot;
  final BoxFit mascotFit;

  const MoodSliderRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.leftLabel,
    required this.rightLabel,
    required this.leftMascot,
    required this.rightMascot,
    this.mascotFit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    const mascotSize = 56.0;
    final leftActive = value == 1;
    final rightActive = value > 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticService.selection();
              onChanged(1);
            },
            child: _AnimatedMascot(
              assetPath: leftMascot,
              size: mascotSize,
              isActive: leftActive,
              fit: mascotFit,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: BbSlider(
              value: value,
              variant: SliderVariant.danger,
              onChanged: onChanged,
              rightLabel: rightLabel,
              leftLabel: leftLabel,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              HapticService.selection();
              onChanged(5);
            },
            child: _AnimatedMascot(
              assetPath: rightMascot,
              size: mascotSize,
              isActive: rightActive,
              fit: mascotFit,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedMascot extends StatefulWidget {
  final String assetPath;
  final double size;
  final bool isActive;
  final BoxFit fit;

  const _AnimatedMascot({
    required this.assetPath,
    required this.size,
    required this.isActive,
    this.fit = BoxFit.contain,
  });

  @override
  State<_AnimatedMascot> createState() => _AnimatedMascotState();
}

class _AnimatedMascotState extends State<_AnimatedMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;
  bool _wasActive = false;

  @override
  void initState() {
    super.initState();
    _wasActive = widget.isActive;
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_bounceController);
  }

  @override
  void didUpdateWidget(_AnimatedMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_wasActive) {
      _bounceController.forward(from: 0);
    }
    _wasActive = widget.isActive;
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetScale = widget.isActive ? 1.1 : 0.9;
    final targetOpacity = widget.isActive ? 1.0 : 0.4;

    return AnimatedBuilder(
      animation: _bounceController,
      builder: (context, child) {
        return AnimatedOpacity(
          opacity: targetOpacity,
          duration: AppConstants.animMedium,
          child: AnimatedScale(
            scale: _bounceController.isAnimating
                ? _bounceAnimation.value
                : targetScale,
            duration: AppConstants.animMedium,
            child: child,
          ),
        );
      },
      child: MascotImage(
        assetPath: widget.assetPath,
        width: widget.size,
        height: widget.size,
        fit: widget.fit,
      ),
    );
  }
}
