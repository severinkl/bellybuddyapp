import 'package:belly_buddy/config/constants.dart';

class SplashConfig {
  final Duration minDelay;
  final Duration animationDuration;
  final Duration fadeOutDuration;
  final bool preloadImages;

  const SplashConfig({
    required this.minDelay,
    required this.animationDuration,
    required this.fadeOutDuration,
    required this.preloadImages,
  });

  static const production = SplashConfig(
    minDelay: Duration(milliseconds: 1000),
    animationDuration: AppConstants.animSlower,
    fadeOutDuration: AppConstants.animMedium,
    preloadImages: true,
  );

  static const test = SplashConfig(
    minDelay: Duration.zero,
    animationDuration: Duration.zero,
    fadeOutDuration: Duration.zero,
    preloadImages: false,
  );
}
