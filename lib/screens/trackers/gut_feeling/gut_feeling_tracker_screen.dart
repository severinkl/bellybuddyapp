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
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_slider.dart';
import '../../../widgets/common/bb_success_overlay.dart';
import '../../../widgets/common/mascot_image.dart';

class GutFeelingTrackerScreen extends ConsumerStatefulWidget {
  const GutFeelingTrackerScreen({super.key});

  @override
  ConsumerState<GutFeelingTrackerScreen> createState() =>
      _GutFeelingTrackerScreenState();
}

class _GutFeelingTrackerScreenState
    extends ConsumerState<GutFeelingTrackerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final DateTime _trackedAt = DateTime.now();
  bool _isSaving = false;
  bool _showSuccess = false;

  // Bauchgefühl values
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
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
      await ref.read(entriesProvider.notifier).addGutFeeling(entry);
      setState(() => _showSuccess = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler beim Speichern.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return BbSuccessOverlay(
        message: 'Eintrag gespeichert!',
        onDismissed: () {
          if (mounted) context.go(RoutePaths.dashboard);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Wie geht es dir?'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.foreground,
          unselectedLabelColor: AppTheme.mutedForeground,
          onTap: (_) => HapticService.light(),
          tabs: const [
            Tab(text: 'Bauchgefühl'),
            Tab(text: 'Stimmung'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _BauchgefuehlTab(
                  bloating: _bloating,
                  gas: _gas,
                  cramps: _cramps,
                  fullness: _fullness,
                  onBloatingChanged: (v) => setState(() => _bloating = v),
                  onGasChanged: (v) => setState(() => _gas = v),
                  onCrampsChanged: (v) => setState(() => _cramps = v),
                  onFullnessChanged: (v) => setState(() => _fullness = v),
                ),
                _StimmungTab(
                  stress: _stress,
                  happiness: _happiness,
                  energy: _energy,
                  focus: _focus,
                  bodyFeel: _bodyFeel,
                  onStressChanged: (v) => setState(() => _stress = v),
                  onHappinessChanged: (v) => setState(() => _happiness = v),
                  onEnergyChanged: (v) => setState(() => _energy = v),
                  onFocusChanged: (v) => setState(() => _focus = v),
                  onBodyFeelChanged: (v) => setState(() => _bodyFeel = v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: BbButton(
              label: 'Speichern',
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodSliderRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final String? leftLabel;
  final String rightLabel;
  final String leftMascot;
  final String rightMascot;
  final double mascotScale;

  const _MoodSliderRow({
    required this.value,
    required this.onChanged,
    this.leftLabel,
    required this.rightLabel,
    required this.leftMascot,
    required this.rightMascot,
    this.mascotScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final mascotSize = 48.0 * mascotScale;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticService.selection();
              onChanged(1);
            },
            child: MascotImage(
              assetPath: leftMascot,
              width: mascotSize,
              height: mascotSize,
            ),
          ),
          Expanded(
            child: BbSlider(
              value: value,
              variant: SliderVariant.danger,
              onChanged: onChanged,
              rightLabel: rightLabel,
              leftLabel: leftLabel,
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticService.selection();
              onChanged(5);
            },
            child: MascotImage(
              assetPath: rightMascot,
              width: mascotSize,
              height: mascotSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _BauchgefuehlTab extends StatelessWidget {
  final int bloating, gas, cramps, fullness;
  final ValueChanged<int> onBloatingChanged, onGasChanged, onCrampsChanged, onFullnessChanged;

  const _BauchgefuehlTab({
    required this.bloating,
    required this.gas,
    required this.cramps,
    required this.fullness,
    required this.onBloatingChanged,
    required this.onGasChanged,
    required this.onCrampsChanged,
    required this.onFullnessChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wie ist dein Bauchgefühl?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _MoodSliderRow(
            value: bloating,
            onChanged: onBloatingChanged,
            rightLabel: 'Blähbauch',
            leftMascot: AppConstants.mascotHappyStomach,
            rightMascot: AppConstants.mascotBloatingStomach,
            mascotScale: 1.5,
          ),
          _MoodSliderRow(
            value: gas,
            onChanged: onGasChanged,
            rightLabel: 'Blähungen',
            leftMascot: AppConstants.mascotZen,
            rightMascot: AppConstants.mascotFlatulance,
            mascotScale: 1.5,
          ),
          _MoodSliderRow(
            value: cramps,
            onChanged: onCrampsChanged,
            rightLabel: 'Krämpfe',
            leftMascot: AppConstants.mascotNoCramp,
            rightMascot: AppConstants.mascotCramp,
            mascotScale: 1.5,
          ),
          _MoodSliderRow(
            value: fullness,
            onChanged: onFullnessChanged,
            rightLabel: 'Völlegefühl',
            leftMascot: AppConstants.mascotInLove,
            rightMascot: AppConstants.mascotFullness,
            mascotScale: 1.5,
          ),
        ],
      ),
    );
  }
}

class _StimmungTab extends StatelessWidget {
  final int stress, happiness, energy, focus, bodyFeel;
  final ValueChanged<int> onStressChanged, onHappinessChanged, onEnergyChanged,
      onFocusChanged, onBodyFeelChanged;

  const _StimmungTab({
    required this.stress,
    required this.happiness,
    required this.energy,
    required this.focus,
    required this.bodyFeel,
    required this.onStressChanged,
    required this.onHappinessChanged,
    required this.onEnergyChanged,
    required this.onFocusChanged,
    required this.onBodyFeelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wie ist deine Stimmung?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _MoodSliderRow(
            value: stress,
            onChanged: onStressChanged,
            leftLabel: 'entspannt',
            rightLabel: 'gestresst',
            leftMascot: AppConstants.mascotHappy,
            rightMascot: AppConstants.mascotStressed,
          ),
          _MoodSliderRow(
            value: happiness,
            onChanged: onHappinessChanged,
            leftLabel: 'glücklich',
            rightLabel: 'traurig',
            leftMascot: AppConstants.mascotHappy,
            rightMascot: AppConstants.mascotSad,
          ),
          _MoodSliderRow(
            value: energy,
            onChanged: onEnergyChanged,
            leftLabel: 'energiegeladen',
            rightLabel: 'müde',
            leftMascot: AppConstants.mascotEnergetic,
            rightMascot: AppConstants.mascotBored,
          ),
          _MoodSliderRow(
            value: focus,
            onChanged: onFocusChanged,
            leftLabel: 'fokussiert',
            rightLabel: 'unkonzentriert',
            leftMascot: AppConstants.mascotClear,
            rightMascot: AppConstants.mascotUnfocused,
          ),
          _MoodSliderRow(
            value: bodyFeel,
            onChanged: onBodyFeelChanged,
            leftLabel: 'wohl',
            rightLabel: 'unwohl',
            leftMascot: AppConstants.mascotCool,
            rightMascot: AppConstants.mascotNervous,
          ),
        ],
      ),
    );
  }
}
