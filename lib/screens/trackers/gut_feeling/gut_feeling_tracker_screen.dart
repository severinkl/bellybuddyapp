import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../config/app_theme.dart';
import '../../../models/gut_feeling_entry.dart';
import '../../../providers/entries_provider.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/save_helper.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/tracker_screen_scaffold.dart';
import 'widgets/bauchgefuehl_tab.dart';
import 'widgets/stimmung_tab.dart';

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

  @override
  Widget build(BuildContext context) {
    return TrackerScreenScaffold(
      title: 'Wie geht es dir?',
      showSuccess: _showSuccess,
      successMessage: 'Eintrag gespeichert!',
      body: Column(
        children: [
          // Tab bar placed below the AppBar via the body
          Material(
            color: AppTheme.screenBackground,
            child: TabBar(
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
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                BauchgefuehlTab(
                  bloating: _bloating,
                  gas: _gas,
                  cramps: _cramps,
                  fullness: _fullness,
                  onBloatingChanged: (v) => setState(() => _bloating = v),
                  onGasChanged: (v) => setState(() => _gas = v),
                  onCrampsChanged: (v) => setState(() => _cramps = v),
                  onFullnessChanged: (v) => setState(() => _fullness = v),
                ),
                StimmungTab(
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
