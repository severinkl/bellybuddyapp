import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../widgets/common/bb_scroll_picker.dart';

class HeightWeightStep extends StatelessWidget {
  final int? height;
  final int? weight;
  final ValueChanged<int> onHeightChanged;
  final ValueChanged<int> onWeightChanged;

  const HeightWeightStep({
    super.key,
    this.height,
    this.weight,
    required this.onHeightChanged,
    required this.onWeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    final heights = List.generate(100, (i) => 120 + i);
    final weights = List.generate(150, (i) => 30 + i);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Text(
            'Größe & Gewicht',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Größe',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    BbScrollPicker(
                      items: heights,
                      selectedValue: height,
                      onChanged: onHeightChanged,
                      labelBuilder: (v) => '$v cm',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Gewicht',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    BbScrollPicker(
                      items: weights,
                      selectedValue: weight,
                      onChanged: onWeightChanged,
                      labelBuilder: (v) => '$v kg',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
