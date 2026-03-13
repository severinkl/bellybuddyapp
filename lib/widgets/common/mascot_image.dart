import 'package:flutter/material.dart';

class MascotImage extends StatelessWidget {
  final String assetPath;
  final double width;
  final double height;

  const MascotImage({
    super.key,
    required this.assetPath,
    this.width = 48,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: width,
          height: height,
          child: const Icon(Icons.image_not_supported_outlined, size: 24),
        );
      },
    );
  }
}
