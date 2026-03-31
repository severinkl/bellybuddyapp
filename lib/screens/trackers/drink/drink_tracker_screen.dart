import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/drink_tracker_provider.dart';
import '../../../utils/drink_helpers.dart';
import '../../../utils/save_helper.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/date_time_chips.dart';
import '../../../widgets/common/tracker_screen_scaffold.dart';
import 'widgets/drink_search.dart';
import 'widgets/drink_size_selector.dart';
import 'widgets/quick_drink_grid.dart';

class DrinkTrackerScreen extends ConsumerStatefulWidget {
  const DrinkTrackerScreen({super.key});

  static const trackerKey = Key('drink_tracker_screen');

  @override
  ConsumerState<DrinkTrackerScreen> createState() => _DrinkTrackerScreenState();
}

class _DrinkTrackerScreenState extends ConsumerState<DrinkTrackerScreen> {
  @override
  void initState() {
    super.initState();
    final notifier = ref.read(drinkTrackerProvider.notifier);
    // Reset stale state from previous visit, then reload.
    // Deferred to avoid state change during widget tree construction.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      notifier.reset();
      notifier.loadDrinks();
      notifier.loadTodayTotal();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(drinkTrackerProvider);
    final canSave =
        state.selectedDrink != null &&
        state.selectedAmount != null &&
        state.selectedAmount! > 0;

    return TrackerScreenScaffold(
      trackerKey: DrinkTrackerScreen.trackerKey,
      title: 'Was hast du getrunken? 💧',
      showSuccess: state.showSuccess,
      successMessage: 'Getränk gespeichert!',
      successMascotAsset: AppConstants.mascotEnergetic,
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
                        // Today's total with live preview
                        _buildTodayTotal(state),
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
                // Fixed bottom save button
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.spacingLg,
                    0,
                    AppConstants.spacingLg,
                    AppConstants.spacingLg,
                  ),
                  child: SafeArea(
                    top: false,
                    child: BbButton(
                      label: 'speichern',
                      isLoading: state.isSaving,
                      onPressed: canSave ? _save : null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTodayTotal(DrinkTrackerState state) {
    final pendingAmount = state.selectedAmount ?? 0;
    final totalWithPending = state.todayTotal + pendingAmount;

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
          const Text(
            'Heute: ',
            style: TextStyle(
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
                color: AppTheme.info,
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
            color: AppTheme.info,
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
            '✕',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    await saveWithFeedback(
      context,
      () => ref.read(drinkTrackerProvider.notifier).save(),
    );
  }
}
