import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../services/haptic_service.dart';

class MoodTabSelector extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  const MoodTabSelector({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Row(
        children: [_buildTab(0, 'Bauchgefühl'), _buildTab(1, 'Stimmung')],
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isActive = activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (activeTab != index) {
            HapticService.light();
            onTabChanged(index);
          }
        },
        child: AnimatedContainer(
          duration: AppConstants.animNormal,
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.0),
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isActive ? 0.08 : 0.0),
                blurRadius: isActive ? 8 : 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AnimatedDefaultTextStyle(
            duration: AppConstants.animNormal,
            style: TextStyle(
              fontSize: AppTheme.fontSizeBodyLG,
              fontWeight: FontWeight.w500,
              color: isActive
                  ? AppTheme.foreground
                  : AppTheme.foreground.withValues(alpha: 0.6),
            ),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
