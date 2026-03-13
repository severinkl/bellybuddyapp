import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../models/drink_entry.dart';

class DrinkDetail extends StatelessWidget {
  final DrinkEntry drink;
  final bool isEditing;
  final TextEditingController amountController;
  final TextEditingController notesController;

  const DrinkDetail({
    super.key,
    required this.drink,
    required this.isEditing,
    required this.amountController,
    required this.notesController,
  });

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Menge (ml)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixText: 'ml',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Notizen',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesController,
            maxLines: 3,
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: 'Optionale Notizen...',
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${drink.amountMl} ml',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        if (drink.notes != null) ...[
          const SizedBox(height: 8),
          Text(drink.notes!,
              style: const TextStyle(color: AppTheme.mutedForeground)),
        ],
      ],
    );
  }
}
