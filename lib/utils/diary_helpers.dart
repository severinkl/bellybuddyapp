import '../config/constants.dart';
import '../models/diary_entry.dart';
import '../services/entry_query_service.dart';
import '../utils/gut_feeling_rating.dart';
import 'drink_helpers.dart';

abstract final class DiaryHelpers {
  /// Transforms an [EntryQueryResult] into a flat, time-sorted list of
  /// [DiaryEntry] objects with German-language subtitles.
  static List<DiaryEntry> buildEntries(EntryQueryResult result) {
    final entries = <DiaryEntry>[
      for (final meal in result.meals)
        DiaryEntry(
          id: meal.id,
          type: DiaryEntryType.meal,
          trackedAt: meal.trackedAt,
          title: meal.title,
          subtitle: '${meal.ingredients.length} Zutaten',
          data: MealDiaryData(meal),
        ),
      for (final toilet in result.toiletEntries)
        DiaryEntry(
          id: toilet.id,
          type: DiaryEntryType.toilet,
          trackedAt: toilet.trackedAt,
          title: 'Klo',
          subtitle:
              AppConstants.stoolTypeDescriptions[toilet.stoolType] ?? 'Normal',
          data: ToiletDiaryData(toilet),
        ),
      for (final gut in result.gutFeelings)
        DiaryEntry(
          id: gut.id,
          type: DiaryEntryType.gutFeeling,
          trackedAt: gut.trackedAt,
          title: 'Bauchgefühl',
          subtitle: gutFeelingSubtitle(gut),
          data: GutFeelingDiaryData(gut),
        ),
      for (final drink in result.drinks)
        DiaryEntry(
          id: drink.id,
          type: DiaryEntryType.drink,
          trackedAt: drink.trackedAt,
          title: drink.drinkName,
          subtitle: '${drink.amountMl} ml',
          data: DrinkDiaryData(drink),
        ),
    ]..sort((a, b) => b.trackedAt.compareTo(a.trackedAt));

    return entries;
  }

  /// The day's totals for the Tagebuch („2× Essen · 1,5 L getrunken"),
  /// parts left out at 0. Null when there is nothing to count (no entries,
  /// or only drinks of 0 ml).
  static String? dayTotals(List<DiaryEntry> entries) {
    int count(DiaryEntryType type) =>
        entries.where((e) => e.type == type).length;
    final drunkMl = entries
        .map((e) => e.data)
        .whereType<DrinkDiaryData>()
        .fold<int>(0, (sum, d) => sum + d.drink.amountMl);
    final meals = count(DiaryEntryType.meal);
    final gut = count(DiaryEntryType.gutFeeling);
    final toilet = count(DiaryEntryType.toilet);
    final parts = [
      if (meals > 0) '$meals× Essen',
      if (drunkMl > 0) '${DrinkHelpers.formatAmount(drunkMl)} getrunken',
      if (gut > 0) '$gut× Bauchgefühl',
      if (toilet > 0) '$toilet× Klo',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
