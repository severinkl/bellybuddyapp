import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/gut_feeling_entry.dart';
import '../../../providers/entries_provider.dart';
import '../../../router/route_names.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/save_helper.dart';
import '../../../widgets/common/bb_success_overlay.dart';
import 'widgets/bauchgefuehl_tab.dart';
import 'widgets/mood_tab_selector.dart';
import 'widgets/pill_button.dart';
import 'widgets/stimmung_tab.dart';

class GutFeelingTrackerScreen extends ConsumerStatefulWidget {
  const GutFeelingTrackerScreen({super.key});

  @override
  ConsumerState<GutFeelingTrackerScreen> createState() =>
      _GutFeelingTrackerScreenState();
}

class _GutFeelingTrackerScreenState
    extends ConsumerState<GutFeelingTrackerScreen>
    with TickerProviderStateMixin {
  final DateTime _trackedAt = DateTime.now();
  int _activeTab = 0;
  bool _isSaving = false;
  bool _showSuccess = false;

  // Bauchgefuehl values
  int _bloating = 1;
  int _gas = 1;
  int _cramps = 1;
  int _fullness = 1;

  // Stimmung values
  int _stress = 1;
  int _happiness = 1;
  int _energy = 1;
  int _focus = 1;
  int _bodyFeel = 1;

  // Entry animations
  late final AnimationController _entryController;
  late final Animation<Offset> _tabSelectorSlide;
  late final Animation<double> _tabSelectorFade;
  late final Animation<Offset> _slidersSlide;
  late final Animation<double> _slidersFade;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _tabSelectorSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    _tabSelectorFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _slidersSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    ));
    _slidersFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
    ));

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final entry = GutFeelingEntry(
      id: const Uuid().v4(),
      trackedAt: _trackedAt,
      bloating: _bloating,
      gas: _gas,
      cramps: _cramps,
      fullness: _fullness,
      stress: _stress,
      happiness: _happiness,
      energy: _energy,
      focus: _focus,
      bodyFeel: _bodyFeel,
    );
    final success = await saveWithFeedback(
      context,
      () => ref.read(entriesProvider.notifier).addGutFeeling(entry),
    );
    if (mounted) {
      if (success) {
        setState(() => _showSuccess = true);
      } else {
        setState(() => _isSaving = false);
      }
    }
  }

  void _onNextOrSave() {
    if (_activeTab == 0) {
      HapticService.light();
      setState(() => _activeTab = 1);
      _entryController.forward(from: 0);
    } else {
      _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return BbSuccessOverlay(
        message: 'Eintrag gespeichert!',
        mascotAsset: AppConstants.mascotHappy,
        onDismissed: () => context.go(RoutePaths.dashboard),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Wie geht es dir?'),
      ),
      body: Stack(
        children: [
          // Scrollable content
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 128),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pill tab selector
                SlideTransition(
                  position: _tabSelectorSlide,
                  child: FadeTransition(
                    opacity: _tabSelectorFade,
                    child: MoodTabSelector(
                      activeTab: _activeTab,
                      onTabChanged: (tab) {
                        setState(() => _activeTab = tab);
                        _entryController.forward(from: 0);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Content area with entry animation
                SlideTransition(
                  position: _slidersSlide,
                  child: FadeTransition(
                    opacity: _slidersFade,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _activeTab == 0
                          ? BauchgefuehlTab(
                              key: const ValueKey('bauchgefuehl'),
                              bloating: _bloating,
                              gas: _gas,
                              cramps: _cramps,
                              fullness: _fullness,
                              onBloatingChanged: (v) =>
                                  setState(() => _bloating = v),
                              onGasChanged: (v) =>
                                  setState(() => _gas = v),
                              onCrampsChanged: (v) =>
                                  setState(() => _cramps = v),
                              onFullnessChanged: (v) =>
                                  setState(() => _fullness = v),
                            )
                          : StimmungTab(
                              key: const ValueKey('stimmung'),
                              stress: _stress,
                              happiness: _happiness,
                              energy: _energy,
                              focus: _focus,
                              bodyFeel: _bodyFeel,
                              onStressChanged: (v) =>
                                  setState(() => _stress = v),
                              onHappinessChanged: (v) =>
                                  setState(() => _happiness = v),
                              onEnergyChanged: (v) =>
                                  setState(() => _energy = v),
                              onFocusChanged: (v) =>
                                  setState(() => _focus = v),
                              onBodyFeelChanged: (v) =>
                                  setState(() => _bodyFeel = v),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Fixed bottom button with gradient backdrop
          _GradientBottomBar(
            label: _activeTab == 0 ? 'weiter' : 'speichern',
            isLoading: _isSaving,
            onPressed: _onNextOrSave,
          ),
        ],
      ),
    );
  }
}

class _GradientBottomBar extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const _GradientBottomBar({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.screenBackground.withValues(alpha: 0.0),
              AppTheme.screenBackground,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
        child: PillButton(
          label: label,
          isLoading: isLoading,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
