import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../router/route_names.dart';
import '../../services/haptic_service.dart';
import '../../widgets/common/mascot_image.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/bb_card.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoAdvanceTimer;
  bool _isPaused = false;

  static const _slides = [
    _SlideData(
      mascot: AppConstants.mascotHappy,
      mascotSize: 192,
      title: 'Verstehe dein Bauchgefühl',
      description:
          'Entdecke, wie deine Ernährung dein Wohlbefinden beeinflusst und finde deinen Weg zu besserer Verdauung.',
    ),
    _SlideData(
      mascot: AppConstants.mascotCool,
      mascotSize: 192,
      title: 'Mahlzeiten einfach tracken',
      description:
          'Mach einfach ein schnelles Foto von deiner Mahlzeit und unsere KI erkennt die Zutaten automatisch.',
    ),
    _SlideData(
      mascot: AppConstants.mascotProfessor,
      mascotSize: 224,
      title: 'Unverträglichkeiten erkennen',
      description:
          'Wir analysieren deine Mahlzeiten und helfen dir dabei, problematische Inhaltsstoffe zu identifizieren.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer.periodic(AppConstants.autoAdvanceDuration, (_) {
      if (!_isPaused && _currentPage < _slides.length - 1 && mounted) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markSeenAndNavigate() async {
    await markOnboardingSeen();
    ref.invalidate(isOnboardedProvider);
    if (mounted) context.go(RoutePaths.auth);
  }

  void _onSkip() => _markSeenAndNavigate();

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _markSeenAndNavigate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _onSkip,
                child: const Text('Überspringen'),
              ),
            ),
            // PageView
            Expanded(
              child: GestureDetector(
                onPanDown: (_) => setState(() => _isPaused = true),
                onPanEnd: (_) => setState(() => _isPaused = false),
                onPanCancel: () => setState(() => _isPaused = false),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) {
                    HapticService.selection();
                    setState(() => _currentPage = index);
                    if (index == _slides.length - 1) {
                      _autoAdvanceTimer?.cancel();
                    }
                  },
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return _OnboardingSlide(data: slide);
                  },
                ),
              ),
            ),
            // Dot indicator
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _slides.length,
                effect: ExpandingDotsEffect(
                  activeDotColor: AppTheme.primary,
                  dotColor: AppTheme.muted,
                  dotHeight: 10,
                  dotWidth: 10,
                  expansionFactor: 2.4,
                  spacing: 8,
                ),
                onDotClicked: (index) {
                  HapticService.light();
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
            // CTA button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: BbButton(
                label: _currentPage == _slides.length - 1 ? 'Los geht\'s' : 'Weiter',
                onPressed: _onNext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideData {
  final String mascot;
  final double mascotSize;
  final String title;
  final String description;

  const _SlideData({
    required this.mascot,
    required this.mascotSize,
    required this.title,
    required this.description,
  });
}

class _OnboardingSlide extends StatelessWidget {
  final _SlideData data;

  const _OnboardingSlide({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MascotImage(
            assetPath: data.mascot,
            width: data.mascotSize,
            height: data.mascotSize,
          ),
          const SizedBox(height: 32),
          BbCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  data.description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.mutedForeground,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
