import 'package:material_ui/material_ui.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';

class BbCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool showBorder;

  /// The corner radius.
  final double radius;

  /// The border's width, while [showBorder].
  final double borderWidth;

  /// Extra constraints on the card, e.g. a minimum height.
  final BoxConstraints? constraints;

  const BbCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.showBorder = true,
    this.radius = AppConstants.radiusLg,
    this.borderWidth = AppConstants.borderWidthSm,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      constraints: constraints,
      padding: padding ?? AppConstants.paddingMd,
      decoration: BoxDecoration(
        color: color ?? AppTheme.card,
        borderRadius: BorderRadius.circular(radius),
        border: showBorder
            ? Border.all(color: AppTheme.border, width: borderWidth)
            : null,
      ),
      // Transparent Material so descendant ListTiles paint ink/selection on a
      // Material ancestor instead of this bg-colored DecoratedBox. Required by
      // Flutter ≥3.42's ListTile assertion; transparent keeps the card bg.
      child: Material(type: MaterialType.transparency, child: child),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
