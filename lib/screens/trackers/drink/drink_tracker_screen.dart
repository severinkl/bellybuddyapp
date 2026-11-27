import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/drink_tracker_provider.dart';
import '../../../router/route_names.dart';
import '../../../services/buddy/buddy_mood_logic.dart';
import '../../../utils/drink_helpers.dart';
import '../../../widgets/buddy/log_success_hero.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/tracker_screen_scaffold.dart';
import '../entry_logger.dart';
import 'widgets/drink_size_selector.dart';
import 'widgets/drink_time_line.dart';
import 'widgets/drink_today_card.dart';
import 'widgets/last_drink_row.dart';
import 'widgets/quick_drink_grid.dart';

class DrinkTrackerScreen extends ConsumerStatefulWidget {
  const DrinkTrackerScreen({super.key, this.initialTrackedAt});

  final DateTime? initialTrackedAt;

  static const trackerKey = Key('drink_tracker_screen');
  static const saveKey = Key('drink_save');

  @override
  ConsumerState<DrinkTrackerScreen> createState() => _DrinkTrackerScreenState();
}

class _DrinkTrackerScreenState extends ConsumerState<DrinkTrackerScreen>
    with EntryLogger {
  /// False until the post-frame reset: the provider outlives the screen, so
  /// the first frame would build the previous visit's state (an open,
  /// autofocused search among it).
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(drinkTrackerProvider.notifier);
    // Reset stale state from previous visit, then reload.
    // Deferred to avoid state change during widget tree construction.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      notifier.reset(trackedAt: widget.initialTrackedAt);
      setState(() => _ready = true);
      notifier.loadDrinks();
      notifier.loadDayTotal();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only what this build shows: typing elsewhere does not rebuild it.
    final (:drink, :amount, :hasLast, :isLoading, :isSaving, :showSuccess) = ref
        .watch(
          drinkTrackerProvider.select(
            (s) => (
              drink: s.selectedDrink,
              amount: s.selectedAmount,
              hasLast: s.lastDrink != null,
              isLoading: s.isLoading,
              isSaving: s.isSaving,
              showSuccess: s.showSuccess,
            ),
          ),
        );
    final notifier = ref.read(drinkTrackerProvider.notifier);
    final moment = logMoment;

    return TrackerScreenScaffold(
      trackerKey: DrinkTrackerScreen.trackerKey,
      title: 'Was hast du getrunken?',
      showSuccess: showSuccess,
      successMessage: 'Getränk gespeichert!',
      successIllustration: moment == null
          ? null
          : LogSuccessHero(moment: moment),
      // Closes with true: the opener knows a drink was saved (the meal
      // success screen then closes as well).
      onSuccessDismissed: () => context.canPop()
          ? context.pop(true)
          : context.go(RoutePaths.dashboard),
      body: !_ready || isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppConstants.paddingLg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const DrinkTodayCard(),
                        AppConstants.gap12,
                        if (hasLast && drink == null) ...[
                          LastDrinkRow(onSave: () => _log(notifier.saveLast)),
                          AppConstants.gap12,
                        ],
                        const QuickDrinkGrid(),
                        AppConstants.gap12,
                        const DrinkSizeSelector(),
                        AppConstants.gap12,
                        const DrinkTimeLine(),
                      ],
                    ),
                  ),
                ),
                // Fixed bottom save button while a drink is chosen, set apart
                // from the content scrolling above it (also with the
                // keyboard open). selectedAmount is set only for a valid
                // amount (1 to 3000 ml).
                if (drink != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.spacingLg,
                      AppConstants.spacingMd,
                      AppConstants.spacingLg,
                      AppConstants.spacingLg,
                    ),
                    child: BbButton(
                      tapKey: DrinkTrackerScreen.saveKey,
                      label: DrinkHelpers.saveLabel(drink, amount),
                      isLoading: isSaving,
                      onPressed: amount == null
                          ? null
                          : () => _log(notifier.save),
                    ),
                  ),
              ],
            ),
    );
  }

  /// Logs a drink through [save] (the chosen drink, or „Wie zuletzt") at
  /// the chosen time.
  Future<void> _log(Future<void> Function() save) => logEntry(
    kind: EntryKind.drink,
    trackedAt: ref.read(drinkTrackerProvider).trackedAt,
    save: save,
    // A save is a no-op without a drink and amount; only a stored entry
    // (shown as success) is a log the Buddy reacts to.
    stored: () => ref.read(drinkTrackerProvider).showSuccess,
  );
}
