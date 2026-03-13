import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class BbPasswordHint extends StatelessWidget {
  final String text;
  final bool isValid;

  const BbPasswordHint({super.key, required this.text, required this.isValid});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isValid ? AppTheme.success : AppTheme.mutedForeground,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isValid ? AppTheme.success : AppTheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
