import 'package:material_ui/material_ui.dart';
import '../../config/constants.dart';

class MascotImage extends StatelessWidget {
  final String assetPath;
  final double width;
  final double height;
  final BoxFit fit;

  /// What VoiceOver/TalkBack call the image; null leaves it out (decorative).
  final String? semanticLabel;

  const MascotImage({
    super.key,
    required this.assetPath,
    this.width = 48,
    this.height = 48,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      // A label is given below so it also covers the error fallback.
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: width,
          height: height,
          child: const Icon(Icons.image_not_supported_outlined, size: 24),
        );
      },
    );

    final drawn = fit == BoxFit.cover
        ? ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            child: image,
          )
        : image;
    final label = semanticLabel;
    if (label == null) return drawn;
    return Semantics(container: true, image: true, label: label, child: drawn);
  }
}
