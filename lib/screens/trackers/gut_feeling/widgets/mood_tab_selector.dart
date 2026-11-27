import 'package:material_ui/material_ui.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../services/haptic_service.dart';
import '../../../../utils/reduced_motion.dart';

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
      padding: const EdgeInsets.all(AppConstants.spacingXs),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Row(
        children: [
          _buildTab(context, 0, 'Bauchgefühl'),
          _buildTab(context, 1, 'Stimmung'),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, int index, String label) {
    final isActive = activeTab == index;
    final duration = ReducedMotion.duration(context, AppConstants.animNormal);
    // One node per tab: its name, selected while its page shows.
    return Expanded(
      child: Semantics(
        container: true,
        button: true,
        selected: isActive,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (activeTab != index) {
              HapticService.light();
              onTabChanged(index);
            }
          },
          child: ExcludeSemantics(
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeInOut,
              // The pill is the tab's tap target, so it is drawn 48 high.
              constraints: const BoxConstraints(
                minHeight: AppConstants.minTapTarget,
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                vertical: AppConstants.spacing10,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.0),
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isActive ? 0.08 : 0.0,
                    ),
                    blurRadius: isActive ? AppConstants.shadowBlurSm : 0,
                    offset: AppConstants.shadowOffsetSm,
                  ),
                ],
              ),
              child: AnimatedDefaultTextStyle(
                duration: duration,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBodyLG,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? AppTheme.foreground
                      : AppTheme.foregroundInactive,
                ),
                child: Text(label, textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
