import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../services/haptic_service.dart';

class SymptomsStep extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const SymptomsStep({super.key, required this.selected, required this.onChanged});

  static const _options = [
    'Belastender Durchfall',
    'Nervige Verstopfung',
    'Unangenehme Blähungen',
    'Übermäßiges Völlegefühl',
    'Hartnäckiger Blähbauch ohne Pupsen',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Text(
            'Welche Beschwerden nerven dich?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ..._options.map((option) {
            final isSelected = selected.contains(option);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    HapticService.selection();
                    final newSelected = List<String>.from(selected);
                    if (isSelected) {
                      newSelected.remove(option);
                    } else {
                      newSelected.add(option);
                    }
                    onChanged(newSelected);
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        isSelected ? AppTheme.primary.withValues(alpha: 0.1) : null,
                    side: BorderSide(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                      width: isSelected ? 2 : 1,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? AppTheme.primary : AppTheme.mutedForeground,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: AppTheme.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
