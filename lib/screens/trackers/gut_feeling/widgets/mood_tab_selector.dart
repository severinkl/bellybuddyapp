import 'package:flutter/material.dart';
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
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          _buildTab(0, 'Bauchgefühl'),
          _buildTab(1, 'Stimmung'),
        ],
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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isActive
                  ? const Color(0xFF302820)
                  : const Color(0xFF302820).withValues(alpha: 0.6),
            ),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
