import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/drink_tracker_provider.dart';
import '../../../router/route_names.dart';
import '../../../services/buddy/buddy_mood_logic.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/drink_helpers.dart';
import '../../../widgets/buddy/log_success_hero.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/date_time_chips.dart';
import '../../../widgets/common/tracker_screen_scaffold.dart';
import '../entry_logger.dart';
import 'widgets/drink_search.dart';
import 'widgets/drink_size_selector.dart';
import 'widgets/quick_drink_grid.dart';

class DrinkTrackerScreen extends ConsumerStatefulWidget {
  const DrinkTrackerScreen({super.key, this.initialTrackedAt});

  final DateTime? initialTrackedAt;

  static const trackerKey = Key('drink_tracker_screen');

  @override
  ConsumerState<DrinkTrackerScreen> createState() => _DrinkTrackerScreenState();
}

class _DrinkTrackerScreenState extends ConsumerState<DrinkTrackerScreen>
    with EntryLogger {
  @override
  void initState() {
    super.initState();
    final notifier = ref.read(drinkTrackerProvider.notifier);
    // Reset stale state from previous visit, then reload.
    // Deferred to avoid state change during widget tree construction.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      notifier.reset(trackedAt: widget.initialTrackedAt);
      notifier.loadDrinks();
      notifier.loadDayTotal();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(drinkTrackerProvider);
    // selectedAmount is set only for a valid amount (1 to 3000 ml).
    final canSave = state.selectedDrink != null && state.selectedAmount != null;
    final moment = logMoment;

    return TrackerScreenScaffold(
      trackerKey: DrinkTrackerScreen.trackerKey,
      title: 'Was hast du getrunken? \u{1F4A7}',
      showSuccess: state.showSuccess,
      successMessage: 'Getränk gespeichert!',
      successIllustration: moment == null
          ? null
          : LogSuccessHero(moment: moment),
      // Closes with true: the opener knows a drink was saved (the meal
      // success screen then closes as well).
      onSuccessDismissed: () => context.canPop()
          ? context.pop(true)
          : context.go(RoutePaths.dashboard),
      body: state.isLoading
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
                        // The day's total with live preview
                        _buildDayTotal(state),
                        AppConstants.gap16,

                        // Date/Time picker — always visible
                        DateTimeChips(
                          value: state.trackedAt,
                          onChanged: ref
                              .read(drinkTrackerProvider.notifier)
                              .setTrackedAt,
                        ),
                        AppConstants.gap16,

                        // Autocomplete search
                        const DrinkSearch(),
                        AppConstants.gap16,

                        // Selected drink chip with deselect
                        if (state.selectedDrink != null) ...[
                          _buildSelectedChip(state),
                          AppConstants.gap16,
                        ],

                        // Quick drink grid (recent drinks)
                        const QuickDrinkGrid(),

                        // Size selector — shown when a drink is selected
                        if (state.selectedDrink != null) ...[
                          AppConstants.gap24,
                          const DrinkSizeSelector(),
                        ],

                        AppConstants.gap24,
                      ],
                    ),
                  ),
                ),
                // Fixed bottom save button, set apart from the content
                // scrolling above it (also with the keyboard open)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.spacingLg,
                    AppConstants.spacingMd,
                    AppConstants.spacingLg,
                    AppConstants.spacingLg,
                  ),
                  child: BbButton(
                    label: 'Speichern',
                    isLoading: state.isSaving,
                    onPressed: canSave ? _save : null,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDayTotal(DrinkTrackerState state) {
    final pendingAmount = state.selectedAmount ?? 0;
    final totalWithPending = state.dayTotal + pendingAmount;
    final dayLabel = isSameDay(state.trackedAt, DateTime.now())
        ? 'Heute: '
        : 'Am ${DateFormat('d.M.').format(state.trackedAt)}: ';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacing12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.water_drop, color: AppTheme.info, size: 20),
          const SizedBox(width: AppConstants.spacingSm),
          Text(
            dayLabel,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.mutedForeground,
            ),
          ),
          Text(
            DrinkHelpers.formatAmount(totalWithPending),
            style: const TextStyle(
              fontSize: AppTheme.fontSizeSubtitle,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          if (pendingAmount > 0) ...[
            const SizedBox(width: AppConstants.spacingXs),
            Text(
              '(+${DrinkHelpers.formatAmount(pendingAmount)})',
              style: const TextStyle(
                fontSize: AppTheme.fontSizeBody,
                fontWeight: FontWeight.w500,
                color: AppTheme.infoText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedChip(DrinkTrackerState state) {
    return Row(
      children: [
        const Text(
          'Ausgewählt:',
          style: TextStyle(
            fontSize: AppTheme.fontSizeBody,
            color: AppTheme.mutedForeground,
          ),
        ),
        const SizedBox(width: AppConstants.spacingSm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacing14,
            vertical: AppConstants.spacingSm,
          ),
          decoration: BoxDecoration(
            color: AppTheme.infoText,
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          ),
          child: Text(
            state.selectedDrink!.name,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: AppConstants.spacingSm),
        GestureDetector(
          onTap: () => ref.read(drinkTrackerProvider.notifier).clearSelection(),
          child: const Text(
            '\u{2715}',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() => logEntry(
    kind: EntryKind.drink,
    trackedAt: ref.read(drinkTrackerProvider).trackedAt,
    save: ref.read(drinkTrackerProvider.notifier).save,
    // save() is a no-op without a drink and amount; only a stored entry
    // (shown as success) is a log the Buddy reacts to.
    stored: () => ref.read(drinkTrackerProvider).showSuccess,
  );
}
