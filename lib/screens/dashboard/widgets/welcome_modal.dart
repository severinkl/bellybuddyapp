import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/mascot_image.dart';

/// Shows the one-time onboarding welcome modal. Dismisses when the user
/// taps "Los geht's"; callers `await` the returned future and then trigger
/// the next tutorial stage (the dashboard spotlight tour).
///
/// Gated upstream by `TutorialNotifier.shouldShow()` — this helper does
/// not check or write any persistence of its own.
Future<void> showWelcomeModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _WelcomeModal(),
  );
}

class _WelcomeModal extends StatelessWidget {
  const _WelcomeModal();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      contentPadding: AppConstants.paddingLg,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MascotImage(
            assetPath: AppConstants.mascotHappy,
            width: AppConstants.mascotSizeMd,
            height: AppConstants.mascotSizeMd,
          ),
          AppConstants.gap16,
          const Text(
            'Willkommen bei Belly Buddy!',
            style: TextStyle(
              fontSize: AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap12,
          const Text(
            'Finde heraus, welche Lebensmittel deine Verdauungsprobleme '
            'auslösen – und was dir wirklich guttut.\n\n'
            'Tracke dein Essen und dein Wohlbefinden regelmäßig, erhalte '
            'persönliches Feedback und entdecke passende Alternativen. '
            'So verstehst du deinen Körper besser und triffst im Alltag '
            'leichter die richtigen Entscheidungen 💛',
            style: TextStyle(fontSize: AppTheme.fontSizeBody),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap24,
          SizedBox(
            width: double.infinity,
            height: AppConstants.buttonHeight,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
              ),
              child: const Text("Los geht's"),
            ),
          ),
        ],
      ),
    );
  }
}
