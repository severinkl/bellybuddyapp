import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';

class MealImageSection extends StatelessWidget {
  final Uint8List? imageBytes;
  final bool isAnalyzing;
  final Future<void> Function(Uint8List bytes, String name) onImagePicked;
  final VoidCallback onClearImage;

  const MealImageSection({
    super.key,
    required this.imageBytes,
    required this.isAnalyzing,
    required this.onImagePicked,
    required this.onClearImage,
  });

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: source, maxWidth: 1024, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await onImagePicked(bytes, file.name);
  }

  @override
  Widget build(BuildContext context) {
    if (imageBytes == null) {
      return _EmptyState(onPickImage: _pickImage);
    }
    return _ImagePreview(
      imageBytes: imageBytes!,
      isAnalyzing: isAnalyzing,
      onClearImage: onClearImage,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function(BuildContext, ImageSource) onPickImage;

  const _EmptyState({required this.onPickImage});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppTheme.border,
          borderRadius: 24,
          dashWidth: 8,
          dashGap: 5,
          strokeWidth: 2,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
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
              Container(
                width: 1,
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                color: AppTheme.border,
              ),
              _PickerButton(
                icon: Icons.photo_library,
                label: 'Galerie',
                color: AppTheme.secondary,
                onTap: () => onPickImage(context, ImageSource.gallery),
              ),
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
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
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
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(imageBytes, fit: BoxFit.cover),
            // X button
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: onClearImage,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close, size: 20),
                ),
              ),
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
                            horizontal: 32, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                                color: AppTheme.primary),
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

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;

  _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.dashWidth,
    required this.dashGap,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final len = min(dashWidth, metric.length - distance);
        final extracted = metric.extractPath(distance, distance + len);
        canvas.drawPath(extracted, paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      color != old.color ||
      borderRadius != old.borderRadius ||
      dashWidth != old.dashWidth ||
      dashGap != old.dashGap ||
      strokeWidth != old.strokeWidth;
}
