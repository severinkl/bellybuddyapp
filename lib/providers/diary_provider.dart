import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/diary_entry.dart';
import '../services/entry_query_service.dart';
import '../services/supabase_service.dart';
import '../utils/gut_feeling_rating.dart';
import '../utils/logger.dart';

export '../models/diary_entry.dart';

const _log = AppLogger('DiaryProvider');

/// Selected date for the diary view
class _DiaryDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void set(DateTime date) => state = date;
}

final diaryDateProvider =
    NotifierProvider<_DiaryDateNotifier, DateTime>(_DiaryDateNotifier.new);

/// Fetches and merges all entry types for the selected date
final diaryEntriesProvider = FutureProvider.family<List<DiaryEntry>, DateTime>((ref, date) async {
  final userId = SupabaseService.userId;
  if (userId == null) return [];

  try {
    final result = await EntryQueryService.fetchEntriesForDateRange(
      userId: userId,
      date: date,
    );

    final entries = <DiaryEntry>[];

    for (final meal in result.meals) {
      entries.add(DiaryEntry(
        id: meal.id,
        type: DiaryEntryType.meal,
        trackedAt: meal.trackedAt,
        title: meal.title,
        subtitle: '${meal.ingredients.length} Zutaten',
        data: MealDiaryData(meal),
      ));
    }

    for (final toilet in result.toiletEntries) {
      entries.add(DiaryEntry(
        id: toilet.id,
        type: DiaryEntryType.toilet,
        trackedAt: toilet.trackedAt,
        title: 'Toilettengang',
        subtitle: AppConstants.stoolTypeDescriptions[toilet.stoolType] ?? 'Normal',
        data: ToiletDiaryData(toilet),
      ));
    }

    for (final gut in result.gutFeelings) {
      final rating = calculateGutFeelingRating(gut);
      entries.add(DiaryEntry(
        id: gut.id,
        type: DiaryEntryType.gutFeeling,
        trackedAt: gut.trackedAt,
        title: 'Bauchgefühl',
        subtitle: rating.level.label,
        data: GutFeelingDiaryData(gut),
      ));
    }

    for (final drink in result.drinks) {
      entries.add(DiaryEntry(
        id: drink.id,
        type: DiaryEntryType.drink,
        trackedAt: drink.trackedAt,
        title: drink.drinkName,
        subtitle: '${drink.amountMl} ml',
        data: DrinkDiaryData(drink),
      ));
    }

    entries.sort((a, b) => b.trackedAt.compareTo(a.trackedAt));
    return entries;
  } catch (e, st) {
    _log.error('failed to load diary entries for $date', e, st);
    rethrow;
  }
});
