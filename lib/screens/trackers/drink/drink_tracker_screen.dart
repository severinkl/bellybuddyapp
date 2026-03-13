import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/drink_tracker_provider.dart';
import '../../../router/route_names.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/save_helper.dart';
import '../../../widgets/common/bb_button.dart';
import '../../../widgets/common/bb_success_overlay.dart';
import '../../../widgets/common/date_time_picker_tile.dart';

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

    if (state.showSuccess) {
      return BbSuccessOverlay(
        message: 'Getränk gespeichert!',
        onDismissed: () {
          if (mounted) context.go(RoutePaths.dashboard);
        },
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.screenBackground,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Was hast du getrunken?'),
      ),
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: state.filteredDrinks.take(20).map((drink) {
                      final isSelected = state.selectedDrink?.id == drink.id;
                      return GestureDetector(
                        onTap: () {
                          HapticService.selection();
                          ref.read(drinkTrackerProvider.notifier).selectDrink(drink);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withValues(alpha: 0.2)
                                : AppTheme.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : AppTheme.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            drink.name,
                            style: TextStyle(
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: AppTheme.foreground,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AppConstants.drinkSizes.map((size) {
                        final isSelected = state.selectedAmount == size;
                        return GestureDetector(
                          onTap: () {
                            HapticService.selection();
                            ref.read(drinkTrackerProvider.notifier).selectAmount(size);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary.withValues(alpha: 0.2)
                                  : AppTheme.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? AppTheme.primary : AppTheme.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              '$size ml',
                              style: TextStyle(
                                fontWeight:
                                    isSelected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
