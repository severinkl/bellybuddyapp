import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../models/drink_entry.dart';
import '../../../../utils/drink_helpers.dart';

class DrinkDetail extends StatelessWidget {
  final DrinkEntry drink;
  final bool isEditing;
  final TextEditingController amountController;

  const DrinkDetail({
    super.key,
    required this.drink,
    required this.isEditing,
    required this.amountController,
  });

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Menge (ml)',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppConstants.gap8,
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: amountController,
            builder: (context, amount, _) => TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                suffixText: 'ml',
                errorText: DrinkHelpers.amountError(amount.text),
              ),
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
          style: const TextStyle(
            fontSize: AppTheme.fontSizeTitle,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (drink.notes != null) ...[
          AppConstants.gap8,
          Text(
            drink.notes!,
            style: const TextStyle(color: AppTheme.mutedForeground),
          ),
        ],
      ],
    );
  }
}
