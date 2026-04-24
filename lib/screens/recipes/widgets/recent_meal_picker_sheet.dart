import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/meal_entry.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/user_recipes_provider.dart';
import '../../../repositories/entry_repository.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/logger.dart';

Future<void> showRecentMealPickerSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppConstants.radiusXl),
      ),
    ),
    builder: (_) => const _RecentMealPickerSheet(),
  );
}

class _RecentMealPickerSheet extends ConsumerStatefulWidget {
  const _RecentMealPickerSheet();

  @override
  ConsumerState<_RecentMealPickerSheet> createState() =>
      _RecentMealPickerSheetState();
}

class _RecentMealPickerSheetState
    extends ConsumerState<_RecentMealPickerSheet> {
  static const _log = AppLogger('RecentMealPickerSheet');

  List<MealEntry>? _meals;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMeals();
  }

  Future<void> _fetchMeals() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final meals = await ref
          .read(entryRepositoryProvider)
          .fetchRecentMeals(userId: userId, limit: 20);
      if (mounted) {
        setState(() {
          _meals = meals;
          _loading = false;
        });
      }
    } catch (e, st) {
      _log.error('fetchRecentMeals failed', e, st);
      if (mounted) {
        setState(() {
          _meals = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveMeal(BuildContext context, MealEntry meal) async {
    Navigator.of(context).pop();
    try {
      await ref
          .read(userRecipesProvider.notifier)
          .create(
            title: meal.title,
            ingredients: meal.ingredients,
            imageUrl: meal.imageUrl,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zu Meine Rezepte hinzugefügt')),
        );
      }
    } catch (e, st) {
      _log.error('create recipe from meal failed', e, st);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Fehler beim Speichern')));
      }
    }
  }

  String _subtitle(MealEntry meal) {
    final date = formatDateTimeShort(meal.trackedAt);
    if (meal.ingredients.isEmpty) return date;
    final first3 = meal.ingredients.take(3).join(' · ');
    return '$date · $first3';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.8,
        child: Column(
          children: [
            const SizedBox(height: AppConstants.spacingSm),
            Container(
              width: AppConstants.dragHandleWidth,
              height: AppConstants.dragHandleHeight,
              decoration: BoxDecoration(
                color: AppTheme.muted,
                borderRadius: BorderRadius.circular(
                  AppConstants.dragHandleRadius,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingMd,
              ),
              child: Text(
                'Kürzliche Mahlzeiten',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeTitle,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _meals == null || _meals!.isEmpty
                  ? const Center(
                      child: Text(
                        'Keine kürzlichen Mahlzeiten',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeBody,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _meals!.length,
                      itemBuilder: (context, i) {
                        final meal = _meals![i];
                        return ListTile(
                          title: Text(meal.title),
                          subtitle: Text(
                            _subtitle(meal),
                            style: const TextStyle(
                              fontSize: AppTheme.fontSizeCaption,
                              color: AppTheme.mutedForeground,
                            ),
                          ),
                          onTap: () => _saveMeal(context, meal),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
