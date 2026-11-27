import 'package:material_ui/material_ui.dart';
import '../../config/constants.dart';
import '../../services/haptic_service.dart';
import '../../utils/reduced_motion.dart';

class PressScaleWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleValue;
  final bool enableHaptic;

  /// Whether assistive tech reads the wrapped child as one button.
  final bool semanticsButton;

  const PressScaleWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.scaleValue = 0.98,
    this.enableHaptic = true,
    this.semanticsButton = true,
  });

  @override
  State<PressScaleWrapper> createState() => _PressScaleWrapperState();
}

class _PressScaleWrapperState extends State<PressScaleWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.pressScaleDuration,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: widget.scaleValue,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // With reduced motion the row doesn't shrink while pressed.
    final calm = ReducedMotion.of(context);
    final detector = GestureDetector(
      onTapDown: calm ? null : (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        if (widget.enableHaptic) HapticService.light();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
    if (!widget.semanticsButton) return detector;
    return Semantics(container: true, button: true, child: detector);
  }
}
