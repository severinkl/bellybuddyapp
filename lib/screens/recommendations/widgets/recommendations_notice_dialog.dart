import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/mascot_image.dart';

/// Shows the "no new recommendations for now" notice on the Tipps screen.
/// Informational only: thanks the user, explains that tester feedback is
/// currently being reviewed so there are no new recommendations for now, and
/// links to the feedback form.
///
/// Gated upstream by `recommendationsNoticeSeenProvider` (see
/// `RecommendationsScreen`) so it appears once per app session — this helper
/// does not check or write any state of its own.
Future<void> showRecommendationsNoticeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _RecommendationsNoticeDialog(),
  );
}

class _RecommendationsNoticeDialog extends StatelessWidget {
  const _RecommendationsNoticeDialog();

  Future<void> _openFeedback(BuildContext context) async {
    // Capture the navigator before the async gap — the dialog may rebuild
    // while the external browser is launching.
    final navigator = Navigator.of(context);
    await launchUrl(
      Uri.parse(AppConstants.feedbackFormUrl),
      mode: LaunchMode.externalApplication,
    );
    navigator.pop();
  }

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
            'Danke, dass du dabei bist! 💛',
            style: TextStyle(
              fontSize: AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap12,
          const Text(
            'Danke, dass du Belly Buddy nutzt! Wir werten gerade das Feedback '
            'aus der bisherigen Testphase aus. Deshalb gibt es vorerst keine '
            'neuen Empfehlungen.\n\n'
            'Dein Feedback hilft uns sehr weiter – teile es gerne über unser '
            'Formular.',
            style: TextStyle(fontSize: AppTheme.fontSizeBody),
            textAlign: TextAlign.center,
          ),
          AppConstants.gap24,
          SizedBox(
            width: double.infinity,
            height: AppConstants.buttonHeight,
            child: ElevatedButton(
              onPressed: () => _openFeedback(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
              ),
              child: const Text('Feedback geben'),
            ),
          ),
          AppConstants.gap8,
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Schließen',
              style: TextStyle(color: AppTheme.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}
