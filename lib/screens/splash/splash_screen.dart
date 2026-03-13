import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  bool _fadingOut = false;

  // All mascot images to precache
  static const _imagesToPreload = [
    AppConstants.mascotHappy,
    AppConstants.mascotCool,
    AppConstants.mascotProfessor,
    AppConstants.mascotWink,
    AppConstants.mascotEnergetic,
    AppConstants.mascotNervous,
    AppConstants.mascotClueless,
    AppConstants.mascotSad,
    AppConstants.mascotBored,
    AppConstants.mascotClear,
    AppConstants.mascotUnfocused,
    AppConstants.mascotStressed,
    AppConstants.mascotInLove,
    AppConstants.mascotZen,
    AppConstants.mascotBloatingStomach,
    AppConstants.mascotHappyStomach,
    AppConstants.mascotFlatulance,
    AppConstants.mascotCramp,
    AppConstants.mascotNoCramp,
    AppConstants.mascotFullness,
    AppConstants.susiPhone,
    AppConstants.fuerDichCard,
    AppConstants.toiletPaperIcon,
  ];

  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _preloadAndWait();
    }
  }

  Future<void> _preloadAndWait() async {
    final minDelay = Future.delayed(const Duration(milliseconds: 1000));

    // Precache all images (don't block on errors)
    await Future.wait([
      minDelay,
      ..._imagesToPreload.map((path) {
        return precacheImage(AssetImage(path), context).catchError((_) {});
      }),
    ]);

    if (!mounted) return;
    setState(() => _fadingOut = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _fadingOut ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.card,
              AppTheme.beige,
            ],
          ),
        ),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    AppConstants.logoSvg,
                    width: 96,
                    height: 96,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Belly Buddy',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foreground,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dein Bauchgefühl verstehen',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.mutedForeground,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
