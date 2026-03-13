import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/mascot_image.dart';

class CompletionStep extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSave;

  const CompletionStep({super.key, required this.isSaving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MascotImage(
            assetPath: AppConstants.mascotHappy,
            width: 160,
            height: 160,
          ),
          const SizedBox(height: 32),
          const Text(
            'Alles bereit!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Dein Profil ist fast fertig. Tippe auf den Button, um es zu speichern und loszulegen.',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.mutedForeground,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          BbButton(
            label: 'Profil erstellen',
            isLoading: isSaving,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}
