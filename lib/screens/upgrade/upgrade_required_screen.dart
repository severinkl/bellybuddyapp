import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../services/app_version_service.dart';
import '../../widgets/common/bb_button.dart';

class UpgradeRequiredScreen extends ConsumerWidget {
  const UpgradeRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.screenBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingLg,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(AppConstants.mascotSad, height: 160),
                AppConstants.gap24,
                const Text(
                  'Update erforderlich',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeHeadingLG,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                  ),
                ),
                AppConstants.gap12,
                const Text(
                  'Um Belly Buddy weiter zu nutzen, aktualisiere bitte '
                  'auf die neueste Version.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                AppConstants.gap24,
                BbButton(
                  label: 'Aktualisieren',
                  onPressed: () => AppVersionService().openStore(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
