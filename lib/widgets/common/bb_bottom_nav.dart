import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../router/route_names.dart';
import '../../config/constants.dart';
import '../../services/haptic_service.dart';

class BbBottomNav extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const BbBottomNav({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDiary = currentIndex == 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Wavy separator
        CustomPaint(
          size: Size(MediaQuery.of(context).size.width, 20),
          painter: _WavePainter(
            backgroundColor: isDiary ? AppTheme.background : AppTheme.beige,
          ),
        ),
        // Nav bar
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.navGradientStart, AppTheme.navGradientEnd],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64 + (bottomPadding > 0 ? 0 : 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Home
                  _NavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: 'Home',
                    isActive: currentIndex == 0,
                    onTap: () {
                      HapticService.light();
                      navigationShell.goBranch(0);
                    },
                  ),
                  // Central meal tracker button
                  _CenterButton(
                    onTap: () {
                      HapticService.light();
                      context.push(RoutePaths.mealTracker);
                    },
                  ),
                  // Diary
                  _NavItem(
                    icon: Icons.menu_book_outlined,
                    activeIcon: Icons.menu_book,
                    label: 'Tagebuch',
                    isActive: currentIndex == 1,
                    onTap: () {
                      HapticService.light();
                      navigationShell.goBranch(1);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  final Color backgroundColor;

  _WavePainter({required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Fill background
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw wave filled with nav gradient
    final wavePaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppTheme.navGradientStart, AppTheme.navGradientEnd],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Wave: M0,0 C80,0 120,40 200,40 C280,40 320,0 400,0 L400,40 L0,40 Z
    // Scaled to actual width
    path.moveTo(0, 0);
    path.cubicTo(w * 0.2, 0, w * 0.3, h, w * 0.5, h);
    path.cubicTo(w * 0.7, h, w * 0.8, 0, w, 0);
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      backgroundColor != oldDelegate.backgroundColor;
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive
                  ? AppTheme.foreground
                  : AppTheme.foreground.withValues(alpha: 0.6),
              size: 32,
            ),
            AppConstants.gap4,
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? AppTheme.foreground
                    : AppTheme.foreground.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Circle button — positioned to overflow upward
            Positioned(
              top: -26,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.shadow,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  color: AppTheme.primaryForeground,
                  size: 36,
                ),
              ),
            ),
            // Label at bottom
            const Positioned(
              bottom: 0,
              child: Text(
                'Essen tracken',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
