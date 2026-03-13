import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../widgets/common/bb_scroll_picker.dart';

class BirthYearStep extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onChanged;

  const BirthYearStep({super.key, this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(100, (i) => currentYear - 10 - i);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Text(
            'Wann wurdest du geboren?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          BbScrollPicker(
            items: years,
            selectedValue: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
