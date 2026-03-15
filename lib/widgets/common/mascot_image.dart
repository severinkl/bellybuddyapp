import 'package:flutter/material.dart';
import '../../config/constants.dart';

class MascotImage extends StatelessWidget {
  final String assetPath;
  final double width;
  final double height;
  final BoxFit fit;

  const MascotImage({
    super.key,
    required this.assetPath,
    this.width = 48,
    this.height = 48,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: width,
          height: height,
          child: const Icon(Icons.image_not_supported_outlined, size: 24),
        );
      },
    );

    if (fit == BoxFit.cover) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        child: image,
      );
    }
    return image;
  }
}
