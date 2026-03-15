import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/app_theme.dart';
import '../config/constants.dart';
import '../router/route_names.dart';
import '../widgets/common/mascot_image.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MascotImage(
                  assetPath: AppConstants.mascotClueless,
                  width: 120,
                  height: 120,
                ),
                AppConstants.gap24,
                const Text(
                  'Seite nicht gefunden',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeHeadingLG,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foreground,
                  ),
                ),
                AppConstants.gap8,
                const Text(
                  'Die angeforderte Seite existiert leider nicht.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBodyLG,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                AppConstants.gap32,
                ElevatedButton(
                  onPressed: () => context.go(RoutePaths.dashboard),
                  child: const Text('Zurück zum Dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
