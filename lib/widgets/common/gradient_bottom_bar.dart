import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class GradientBottomBar extends StatelessWidget {
  final Widget child;

  const GradientBottomBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.screenBackground.withValues(alpha: 0.0),
              AppTheme.screenBackground,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
        child: child,
      ),
    );
  }
}
