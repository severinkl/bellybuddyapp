import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../router/route_names.dart';
import '../../services/haptic_service.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/bb_card.dart';
import '../../widgets/common/mascot_image.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _slides = [
    (
      asset: AppConstants.mascotHappy,
      size: 192.0,
      title: 'Verstehe dein Bauchgefühl',
      description:
          'Entdecke, wie deine Ernährung dein Wohlbefinden beeinflusst und finde deinen Weg zu besserer Verdauung.',
    ),
    (
      asset: AppConstants.mascotCool,
      size: 192.0,
      title: 'Mahlzeiten einfach tracken',
      description:
          'Mach einfach ein schnelles Foto von deiner Mahlzeit und unsere KI erkennt die Zutaten automatisch.',
    ),
    (
      asset: AppConstants.mascotProfessor,
      size: 224.0,
      title: 'Unverträglichkeiten erkennen',
      description:
          'Wir analysieren deine Mahlzeiten und helfen dir dabei, problematische Inhaltsstoffe zu identifizieren.',
    ),
  ];

  final _pageController = PageController();
  Timer? _autoAdvanceTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _currentPage = (_currentPage + 1) % _slides.length;
      _pageController.animateToPage(
        _currentPage,
        duration: AppConstants.animSlow,
        curve: Curves.easeInOut,
      );
    });
  }

  void _resetTimer() {
    _autoAdvanceTimer?.cancel();
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) {
                    _currentPage = index;
                    _resetTimer();
                    HapticService.selection();
                  },
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MascotImage(
                          assetPath: slide.asset,
                          width: slide.size,
                          height: slide.size,
                        ),
                        AppConstants.gap32,
                        BbCard(
                          padding: AppConstants.paddingLg,
                          child: Column(
                            children: [
                              Text(
                                slide.title,
                                style: const TextStyle(
                                  fontSize: AppTheme.fontSizeHeading,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.foreground,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              AppConstants.gap12,
                              Text(
                                slide.description,
                                style: const TextStyle(
                                  fontSize: AppTheme.fontSizeBodyLG,
                                  color: AppTheme.mutedForeground,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SmoothPageIndicator(
                controller: _pageController,
                count: _slides.length,
                onDotClicked: (index) {
                  _pageController.animateToPage(
                    index,
                    duration: AppConstants.animMedium,
                    curve: Curves.easeInOut,
                  );
                  _currentPage = index;
                  _resetTimer();
                },
                effect: const ExpandingDotsEffect(
                  activeDotColor: AppTheme.primary,
                  dotColor: AppTheme.muted,
                  dotHeight: 8,
                  dotWidth: 8,
                  expansionFactor: 3,
                ),
              ),
              AppConstants.gap24,
              BbButton(
                label: 'Registrieren',
                onPressed: () => context.go(RoutePaths.registration),
              ),
              AppConstants.gap12,
              TextButton(
                onPressed: () => context.go(RoutePaths.auth),
                child: const Text('Zur Anmeldung'),
              ),
              AppConstants.gap24,
            ],
          ),
        ),
      ),
    );
  }
}
