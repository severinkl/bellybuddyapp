import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../services/haptic_service.dart';

class DietStep extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const DietStep({super.key, this.value, required this.onChanged});

  static const _options = [
    ('alles', 'Alles'),
    ('vegetarisch', 'Vegetarisch'),
    ('vegan', 'Vegan'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Text(
            'Wie ernährst du dich?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ..._options.map((option) {
            final isSelected = value == option.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    HapticService.selection();
                    onChanged(option.$1);
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        isSelected ? AppTheme.primary.withValues(alpha: 0.1) : null,
                    side: BorderSide(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                      width: isSelected ? 2 : 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    option.$2,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: AppTheme.foreground,
                    ),
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
