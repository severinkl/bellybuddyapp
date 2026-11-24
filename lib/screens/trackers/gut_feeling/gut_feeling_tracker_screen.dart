import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/gut_feeling_entry.dart';
import '../../../providers/buddy_events_provider.dart';
import '../../../providers/diary_provider.dart';
import '../../../providers/entries_provider.dart';
import '../../../providers/log_moment.dart';
import '../../../router/navigation_extensions.dart';
import '../../../services/buddy/buddy_mood_logic.dart';
import '../../../services/buddy/log_moment.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/save_helper.dart';
import '../../../widgets/buddy/log_success_hero.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_success_overlay.dart';
import '../../../widgets/common/date_time_chips.dart';
import 'widgets/bauchgefuehl_tab.dart';
import 'widgets/mood_tab_selector.dart';
import 'widgets/stimmung_tab.dart';

class GutFeelingTrackerScreen extends ConsumerStatefulWidget {
  const GutFeelingTrackerScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<GutFeelingTrackerScreen> createState() =>
      _GutFeelingTrackerScreenState();
}

class _GutFeelingTrackerScreenState
    extends ConsumerState<GutFeelingTrackerScreen>
    with TickerProviderStateMixin {
  late DateTime _trackedAt = buildTrackedAt(widget.initialDate);
  int _activeTab = 0;
  bool _isSaving = false;

  /// Set once the entry is saved; shows the success screen.
  LogSentiment? _savedSentiment;

  /// What the entry does, as it is saved; the success page shows it.
  LogMoment? _moment;

  // Bauchgefuehl values
  int _bloating = 1;
  int _gas = 1;
  int _cramps = 1;
  int _fullness = 1;

  // Stimmung values: optional, null until the user sets them
  int? _stress;
  int? _happiness;
  int? _energy;
  int? _focus;
  int? _bodyFeel;

  // Page controller for smooth tab transitions
  late final PageController _pageController;

  // Entry animations
  late final AnimationController _entryController;
  late final Animation<Offset> _tabSelectorSlide;
  late final Animation<double> _tabSelectorFade;
  late final Animation<Offset> _slidersSlide;
  late final Animation<double> _slidersFade;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _entryController = AnimationController(
      vsync: this,
      duration: AppConstants.animSlow,
    );

    _tabSelectorSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
          ),
        );
    _tabSelectorFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slidersSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
          ),
        );
    _slidersFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
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
    _moment = captureLogMoment(
      ref,
      kind: EntryKind.gutFeeling,
      trackedAt: entry.trackedAt,
      sentiment: sentimentForGutFeeling(entry),
    );
    final success = await saveWithFeedback(
      context,
      () => ref.read(entriesProvider.notifier).addGutFeeling(entry),
    );
    if (mounted) {
      if (success) {
        ref.invalidate(diaryEntriesProvider(startOfDay(_trackedAt)));
        final sentiment = sentimentForGutFeeling(entry);
        ref
            .read(buddyEventsProvider.notifier)
            .emit(
              BuddyLogEvent(
                EntryKind.gutFeeling,
                sentiment,
                at: DateTime.now(),
                trackedAt: entry.trackedAt,
              ),
            );
        setState(() => _savedSentiment = sentiment);
      } else {
        setState(() => _isSaving = false);
      }
    }
  }

  void _animateToTab(int tab) {
    _pageController.animateToPage(
      tab,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _onNextOrSave() {
    if (_activeTab == 0) {
      HapticService.light();
      _animateToTab(1);
    } else {
      _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedSentiment = _savedSentiment;
    if (savedSentiment != null) {
      final moment = _moment;
      // After a hard day no celebration: calm, without the „!".
      final hardDay = savedSentiment == LogSentiment.bad;
      return BbSuccessOverlay(
        message: hardDay ? 'Eintrag gespeichert.' : 'Eintrag gespeichert!',
        calm: hardDay,
        subMessage: 'Ist jetzt in deinem Tagebuch eingetragen.',
        illustration: moment == null
            ? null
            : LogSuccessHero(
                moment: moment,
                kind: EntryKind.gutFeeling,
                sentiment: savedSentiment,
              ),
        onDismissed: context.popOrGoDashboard,
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.popOrGoDashboard(),
        ),
        title: const Text('Wie geht es dir?'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingMd,
              AppConstants.spacingMd,
              AppConstants.spacingMd,
              0,
            ),
            child: DateTimeChips(
              value: _trackedAt,
              onChanged: (dt) => setState(() => _trackedAt = dt),
            ),
          ),
          AppConstants.gap8,

          // Pill tab selector (fixed, not scrollable)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingMd,
              AppConstants.spacingSm,
              AppConstants.spacingMd,
              0,
            ),
            child: SlideTransition(
              position: _tabSelectorSlide,
              child: FadeTransition(
                opacity: _tabSelectorFade,
                child: MoodTabSelector(
                  activeTab: _activeTab,
                  onTabChanged: (tab) {
                    HapticService.light();
                    setState(() => _activeTab = tab);
                    _animateToTab(tab);
                  },
                ),
              ),
            ),
          ),
          AppConstants.gap24,

          // PageView for smooth tab transitions
          Expanded(
            child: SlideTransition(
              position: _slidersSlide,
              child: FadeTransition(
                opacity: _slidersFade,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    if (_activeTab != index) {
                      HapticService.light();
                      setState(() => _activeTab = index);
                    }
                  },
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppConstants.spacingMd,
                        0,
                        AppConstants.spacingMd,
                        AppConstants.spacingMd,
                      ),
                      child: BauchgefuehlTab(
                        bloating: _bloating,
                        gas: _gas,
                        cramps: _cramps,
                        fullness: _fullness,
                        onBloatingChanged: (v) => setState(() => _bloating = v),
                        onGasChanged: (v) => setState(() => _gas = v),
                        onCrampsChanged: (v) => setState(() => _cramps = v),
                        onFullnessChanged: (v) => setState(() => _fullness = v),
                      ),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppConstants.spacingMd,
                        0,
                        AppConstants.spacingMd,
                        AppConstants.spacingMd,
                      ),
                      child: StimmungTab(
                        stress: _stress,
                        happiness: _happiness,
                        energy: _energy,
                        focus: _focus,
                        bodyFeel: _bodyFeel,
                        onStressChanged: (v) => setState(() => _stress = v),
                        onHappinessChanged: (v) =>
                            setState(() => _happiness = v),
                        onEnergyChanged: (v) => setState(() => _energy = v),
                        onFocusChanged: (v) => setState(() => _focus = v),
                        onBodyFeelChanged: (v) => setState(() => _bodyFeel = v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Pinned bottom button: the pages end above it, so nothing sits
          // under it at rest
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingMd,
                AppConstants.spacingSm,
                AppConstants.spacingMd,
                AppConstants.spacingMd,
              ),
              child: BbButton(
                label: _activeTab == 0 ? 'Weiter' : 'Speichern',
                isLoading: _isSaving,
                onPressed: _onNextOrSave,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
