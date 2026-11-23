import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/buddy_provider.dart';
import '../../providers/diary_provider.dart';
import '../../providers/entries_provider.dart';
import '../../services/buddy/daily_care.dart';
import '../../utils/date_format_utils.dart';
import '../../screens/dashboard/widgets/tutorial/tutorial_keys.dart';
import '../../services/haptic_service.dart';
import '../log_sheet/log_sheet.dart';

/// The bottom bar: Home · Tagebuch · (+) · Entdecken · Ich. The tabs are the
/// shell's branches (in that order); the plus in the middle opens the
/// „Eintragen" sheet.
class BbBottomNav extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  static const navHomeKey = Key('bottom_nav_home');
  static const navDiaryKey = Key('bottom_nav_diary');
  static const navDiscoverKey = Key('bottom_nav_discover');
  static const navMeKey = Key('bottom_nav_me');
  static const centerButtonKey = Key('bottom_nav_center_button');

  // The shell's branch indices.
  static const _homeBranch = 0;
  static const _diaryBranch = 1;
  static const _discoverBranch = 2;
  static const _meBranch = 3;

  const BbBottomNav({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    void goBranch(int index) {
      HapticService.light();
      navigationShell.goBranch(index);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Wavy separator
        CustomPaint(
          size: Size(MediaQuery.of(context).size.width, 20),
          painter: const _WavePainter(),
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
                children: [
                  Expanded(
                    child: _NavItem(
                      tapKey: navHomeKey,
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: 'Home',
                      isActive: currentIndex == _homeBranch,
                      onTap: () => goBranch(_homeBranch),
                    ),
                  ),
                  Expanded(
                    child: KeyedSubtree(
                      key: TutorialKeys.tagebuch,
                      child: _NavItem(
                        tapKey: navDiaryKey,
                        icon: Icons.menu_book_outlined,
                        activeIcon: Icons.menu_book,
                        label: 'Tagebuch',
                        isActive: currentIndex == _diaryBranch,
                        onTap: () {
                          // The tab always opens on today.
                          ref
                              .read(diaryDateProvider.notifier)
                              .set(startOfDay(ref.read(buddyClockProvider)()));
                          goBranch(_diaryBranch);
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: _CenterButton(
                      tapKey: centerButtonKey,
                      onTap: () {
                        HapticService.light();
                        _openLogSheet(context, ref);
                      },
                    ),
                  ),
                  Expanded(
                    child: KeyedSubtree(
                      key: TutorialKeys.entdecken,
                      child: _NavItem(
                        tapKey: navDiscoverKey,
                        icon: Icons.explore_outlined,
                        activeIcon: Icons.explore,
                        label: 'Entdecken',
                        isActive: currentIndex == _discoverBranch,
                        onTap: () => goBranch(_discoverBranch),
                      ),
                    ),
                  ),
                  Expanded(
                    child: KeyedSubtree(
                      key: TutorialKeys.ich,
                      child: _NavItem(
                        tapKey: navMeKey,
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        label: 'Ich',
                        isActive: currentIndex == _meBranch,
                        onTap: () => goBranch(_meBranch),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Opens the „Eintragen" sheet: on the Tagebuch for the day it shows,
  /// on the other tabs for now. For today, the need Home suggests next
  /// ([nextCareAction]) is highlighted.
  void _openLogSheet(BuildContext context, WidgetRef ref) {
    final now = ref.read(buddyClockProvider)();
    final day = navigationShell.currentIndex == _diaryBranch
        ? ref.read(diaryDateProvider)
        : now;
    final suggested = isSameDay(day, now)
        ? nextCareAction(
            DailyCare.fromEntries(ref.read(entriesProvider), now),
            now,
          ).need
        : null;
    unawaited(showLogSheet(context, day: day, now: now, suggested: suggested));
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Fill background
    final bgPaint = Paint()..color = AppTheme.background;
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
  bool shouldRepaint(_WavePainter oldDelegate) => false;
}

class _NavItem extends StatelessWidget {
  final Key? tapKey;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    this.tapKey,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: tapKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
          _BarLabel(
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
    );
  }
}

class _CenterButton extends StatelessWidget {
  final VoidCallback onTap;
  final Key tapKey;

  const _CenterButton({required this.onTap, required this.tapKey});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: tapKey,
      onTap: onTap,
      child: SizedBox(
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Circle button — positioned to overflow upward
            Positioned(
              top: -26,
              child: Container(
                key: TutorialKeys.plus,
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
              left: 0,
              right: 0,
              bottom: 0,
              child: _BarLabel(
                'Eintragen',
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

/// A slot's label: one line, shrunk to fit its slot when needed (five slots
/// on a narrow phone with large text).
class _BarLabel extends StatelessWidget {
  const _BarLabel(this.label, {required this.style});

  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacing2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, maxLines: 1, style: style),
      ),
    );
  }
}
