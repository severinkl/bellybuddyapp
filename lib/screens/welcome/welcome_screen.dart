import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../router/route_names.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/bb_card.dart';
import '../../widgets/common/mascot_image.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              const MascotImage(
                assetPath: AppConstants.mascotHappy,
                width: 192,
                height: 192,
              ),
              const SizedBox(height: 32),
              const BbCard(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Willkommen bei Belly Buddy',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foreground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Entdecke, wie deine Ernährung dein Wohlbefinden beeinflusst und finde deinen Weg zu besserer Verdauung.',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.mutedForeground,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              BbButton(
                label: 'Registrieren',
                onPressed: () => context.go(RoutePaths.registration),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go(RoutePaths.auth),
                child: const Text('Überspringen'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
