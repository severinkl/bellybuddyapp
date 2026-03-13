import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class BbCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool showBorder;

  const BbCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: showBorder ? Border.all(color: AppTheme.border, width: 0.5) : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
