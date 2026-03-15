import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import 'mascot_image.dart';

/// Consistent loading state widget with mascot and message.
class BbLoadingState extends StatelessWidget {
  final String message;
  final String mascotAsset;

  const BbLoadingState({
    super.key,
    this.message = 'Laden...',
    this.mascotAsset = AppConstants.mascotHappy,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MascotImage(
            assetPath: mascotAsset,
            width: 96,
            height: 96,
          ),
          AppConstants.gap16,
          Text(
            message,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeSubtitle,
              color: AppTheme.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Consistent error state widget with mascot, message, and retry button.
class BbErrorState extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;
  final String mascotAsset;

  const BbErrorState({
    super.key,
    this.message = 'Ein Fehler ist aufgetreten.',
    this.retryLabel = 'Erneut versuchen',
    this.onRetry,
    this.mascotAsset = AppConstants.mascotSad,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MascotImage(
            assetPath: mascotAsset,
            width: 96,
            height: 96,
          ),
          AppConstants.gap16,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeBodyLG,
                color: AppTheme.mutedForeground,
              ),
            ),
          ),
          if (onRetry != null) ...[
            AppConstants.gap16,
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(retryLabel),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 48),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
