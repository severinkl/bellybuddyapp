import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/drink_tracker_provider.dart';
import '../../../utils/save_helper.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/date_time_picker_tile.dart';
import '../../../widgets/common/selectable_item_grid.dart';
import '../../../widgets/common/tracker_screen_scaffold.dart';

class DrinkTrackerScreen extends ConsumerStatefulWidget {
  const DrinkTrackerScreen({super.key});

  @override
  ConsumerState<DrinkTrackerScreen> createState() =>
      _DrinkTrackerScreenState();
}

class _DrinkTrackerScreenState extends ConsumerState<DrinkTrackerScreen> {
  final _searchController = TextEditingController();
  final _customAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(drinkTrackerProvider.notifier);
    notifier.loadDrinks();
    notifier.loadTodayTotal();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(drinkTrackerProvider);

    return TrackerScreenScaffold(
      title: 'Was hast du getrunken?',
      showSuccess: state.showSuccess,
      successMessage: 'Getränk gespeichert!',
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Today's total
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.water_drop, color: AppTheme.info),
                        const SizedBox(width: 8),
                        Text(
                          'Heute: ${state.todayTotal} ml',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.info,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Getränk suchen...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: ref.read(drinkTrackerProvider.notifier).filterDrinks,
                  ),
                  const SizedBox(height: 16),

                  // Drink grid
                  SelectableItemGrid(
                    items: state.filteredDrinks.take(20).toList(),
                    selectedValue: state.selectedDrink,
                    onSelected: ref.read(drinkTrackerProvider.notifier).selectDrink,
                    labelBuilder: (drink) => drink.name,
                  ),

                  if (state.selectedDrink != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Menge',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    // Predefined sizes
                    SelectableItemGrid(
                      items: AppConstants.drinkSizes,
                      selectedValue: state.selectedAmount,
                      onSelected: ref.read(drinkTrackerProvider.notifier).selectAmount,
                      labelBuilder: (size) => '$size ml',
                    ),
                    const SizedBox(height: 8),
                    // Custom amount
                    TextField(
                      controller: _customAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Andere Menge (ml)',
                      ),
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null && parsed > 0) {
                          ref.read(drinkTrackerProvider.notifier).selectAmount(parsed);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date/Time
                    DateTimePickerTile(
                      value: state.trackedAt,
                      onChanged: ref.read(drinkTrackerProvider.notifier).setTrackedAt,
                    ),
                    const SizedBox(height: 24),
                    BbButton(
                      label: 'Getränk speichern',
                      isLoading: state.isSaving,
                      onPressed: state.selectedAmount != null ? _save : null,
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _save() async {
    await saveWithFeedback(
      context,
      () => ref.read(drinkTrackerProvider.notifier).save(),
    );
  }
}
