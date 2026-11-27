import 'dart:ui';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../utils/logger.dart';
import '../../../../utils/reduced_motion.dart';
import '../../../../utils/url_utils.dart';
import '../../../../widgets/common/circle_icon_button.dart';
import '../../../../widgets/common/dashed_border_painter.dart';
import '../../../../widgets/common/signed_path_image.dart';

/// Picks a photo from [source]; null when the user cancels.
typedef MealImagePicker = Future<XFile?> Function(ImageSource source);

Future<XFile?> _pickWithImagePicker(ImageSource source) =>
    ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 85);

const _log = AppLogger('MealImageSection');

class MealImageSection extends StatelessWidget {
  final Uint8List? imageBytes;
  final bool isAnalyzing;

  /// Optional existing remote image URL (edit mode). Shown when [imageBytes]
  /// is null so the user can see the currently saved image and clear it.
  final String? initialImageUrl;

  final Future<void> Function(Uint8List bytes, String name) onImagePicked;
  final VoidCallback onClearImage;

  /// When non-null, adds a third "Rezept" button to the empty-state row.
  final VoidCallback? onPickRecipe;

  /// Picks the photo (default: the system camera / photo picker).
  final MealImagePicker pickImage;

  /// Opens the Settings app when photo access was denied.
  final UrlOpener openUrl;

  const MealImageSection({
    super.key,
    required this.imageBytes,
    required this.isAnalyzing,
    required this.onImagePicked,
    required this.onClearImage,
    this.initialImageUrl,
    this.onPickRecipe,
    this.pickImage = _pickWithImagePicker,
    this.openUrl = launchUrl,
  });

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final XFile? file;
    try {
      file = await pickImage(source);
    } on PlatformException catch (e, st) {
      if (!context.mounted) return;
      // image_picker: camera_access_denied / photo_access_denied.
      if (e.code.endsWith('_access_denied')) {
        await _showAccessDenied(context, camera: source == ImageSource.camera);
      } else {
        _log.error('picking an image failed', e, st);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Das Bild konnte nicht geladen werden.'),
          ),
        );
      }
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await onImagePicked(bytes, file.name);
  }

  /// Explains that the app may not use the camera ([camera]) or the photos,
  /// and offers the Settings app, where the user can allow it.
  Future<void> _showAccessDenied(
    BuildContext context, {
    required bool camera,
  }) async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          camera
              ? 'Kein Zugriff auf die Kamera'
              : 'Kein Zugriff auf deine Fotos',
        ),
        content: Text(
          camera
              ? 'Erlaube Belly Buddy in den Einstellungen den Zugriff auf die '
                    'Kamera, um deine Mahlzeit zu fotografieren.'
              : 'Erlaube Belly Buddy in den Einstellungen den Zugriff auf '
                    'deine Fotos, um ein Bild deiner Mahlzeit auszuwählen.',
        ),
        // Too wide for one row on a phone: stacked, centered, the way out
        // („Einstellungen öffnen") on top.
        actionsOverflowAlignment: OverflowBarAlignment.center,
        actionsOverflowDirection: VerticalDirection.up,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Einstellungen öffnen'),
          ),
        ],
      ),
    );
    if (openSettings != true || !context.mounted) return;
    await openAppSettings(context, open: openUrl);
  }

  @override
  Widget build(BuildContext context) {
    if (imageBytes != null) {
      return _ImagePreview(
        imageBytes: imageBytes!,
        isAnalyzing: isAnalyzing,
        onClearImage: onClearImage,
      );
    }
    if (initialImageUrl != null) {
      return _UrlImagePreview(
        imageUrl: initialImageUrl!,
        onClearImage: onClearImage,
      );
    }
    return _EmptyState(onPickImage: _pickImage, onPickRecipe: onPickRecipe);
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function(BuildContext, ImageSource) onPickImage;
  final VoidCallback? onPickRecipe;

  const _EmptyState({required this.onPickImage, this.onPickRecipe});

  static Widget _divider() => Container(
    width: 1,
    height: 48,
    margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
    color: AppTheme.border,
  );

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: CustomPaint(
        foregroundPainter: const DashedBorderPainter(
          radius: AppConstants.radiusXl,
          dashLength: AppConstants.dashLengthLg,
          dashGap: AppConstants.dashGapLg,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PickerButton(
                icon: Icons.camera_alt,
                label: 'Kamera',
                color: AppTheme.primary,
                onTap: () => onPickImage(context, ImageSource.camera),
              ),
              _divider(),
              _PickerButton(
                icon: Icons.photo_library,
                label: 'Galerie',
                color: AppTheme.secondary,
                onTap: () => onPickImage(context, ImageSource.gallery),
              ),
              if (onPickRecipe != null) ...[
                _divider(),
                _PickerButton(
                  icon: Icons.restaurant_menu,
                  label: 'Rezept',
                  color: AppTheme.navGradientStart,
                  onTap: onPickRecipe!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PickerButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: AppTheme.foreground, size: 28),
          ),
          AppConstants.gap8,
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeCaptionLG,
              color: AppTheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final Uint8List imageBytes;
  final bool isAnalyzing;
  final VoidCallback onClearImage;

  const _ImagePreview({
    required this.imageBytes,
    required this.isAnalyzing,
    required this.onClearImage,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(imageBytes, fit: BoxFit.cover),
            Positioned(
              top: AppConstants.spacing12,
              right: AppConstants.spacing12,
              child: _ClearPhotoButton(onTap: onClearImage),
            ),
            // Analysis overlay
            if (isAnalyzing)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingXl,
                          vertical: AppConstants.spacingLg,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusRound,
                          ),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppTheme.primary),
                            AppConstants.gap16,
                            Text(
                              'Analysiere...',
                              style: TextStyle(
                                fontSize: AppTheme.fontSizeSubtitle,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            AppConstants.gap4,
                            Text(
                              'KI erkennt Zutaten',
                              style: TextStyle(
                                fontSize: AppTheme.fontSizeCaptionLG,
                                color: AppTheme.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UrlImagePreview extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onClearImage;

  const _UrlImagePreview({required this.imageUrl, required this.onClearImage});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SignedPathImage(
              pathOrUrl: imageUrl,
              placeholder: ReducedMotion.shimmer(
                context,
                baseColor: AppTheme.muted,
                highlightColor: AppTheme.background,
                child: Container(color: AppTheme.muted),
              ),
              errorWidget: Container(color: AppTheme.muted),
            ),
            Positioned(
              top: AppConstants.spacing12,
              right: AppConstants.spacing12,
              child: _ClearPhotoButton(onTap: onClearImage),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ✕ over a photo: removes it (the picked one or the saved one).
class _ClearPhotoButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearPhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) => CircleIconButton(
    icon: Icons.close,
    semanticLabel: 'Foto entfernen',
    size: AppConstants.minTapTarget,
    iconSize: AppConstants.iconSizeClose,
    backgroundColor: AppTheme.card,
    raised: true,
    onPressed: onTap,
  );
}
