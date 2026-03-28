import 'package:belly_buddy/config/splash_screen_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final splashConfigProvider = Provider<SplashConfig>((ref) {
  return SplashConfig.production;
});
