import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal_entry.dart';
import '../models/toilet_entry.dart';
import '../models/gut_feeling_entry.dart';
import '../models/drink_entry.dart';
import '../services/supabase_service.dart';
import '../utils/gut_feeling_rating.dart';

enum DiaryEntryType { meal, toilet, gutFeeling, drink }

class DiaryEntry {
  final String id;
  final DiaryEntryType type;
  final DateTime trackedAt;
  final String title;
  final String subtitle;
  final dynamic data;

  const DiaryEntry({
    required this.id,
    required this.type,
    required this.trackedAt,
    required this.title,
    required this.subtitle,
    this.data,
  });
}

/// Selected date for the diary view
final diaryDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Fetches and merges all entry types for the selected date
final diaryEntriesProvider = FutureProvider.family<List<DiaryEntry>, DateTime>((ref, date) async {
  final userId = SupabaseService.userId;
  if (userId == null) return [];

  final startOfDay = DateTime(date.year, date.month, date.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  final start = startOfDay.toIso8601String();
  final end = endOfDay.toIso8601String();

  final results = await Future.wait([
    SupabaseService.client
        .from('meal_entries')
        .select()
        .eq('user_id', userId)
        .gte('tracked_at', start)
        .lt('tracked_at', end),
    SupabaseService.client
        .from('toilet_entries')
        .select()
        .eq('user_id', userId)
        .gte('tracked_at', start)
        .lt('tracked_at', end),
    SupabaseService.client
        .from('gut_feeling_entries')
        .select()
        .eq('user_id', userId)
        .gte('tracked_at', start)
        .lt('tracked_at', end),
    SupabaseService.client
        .from('drink_entries')
        .select('*, drinks(name)')
        .eq('user_id', userId)
        .gte('tracked_at', start)
        .lt('tracked_at', end),
  ]);

  final entries = <DiaryEntry>[];

  for (final row in results[0] as List) {
    final meal = MealEntry.fromJson(row);
    entries.add(DiaryEntry(
      id: meal.id,
      type: DiaryEntryType.meal,
      trackedAt: meal.trackedAt,
      title: meal.title,
      subtitle: '${meal.ingredients.length} Zutaten',
      data: meal,
    ));
  }

  for (final row in results[1] as List) {
    final toilet = ToiletEntry.fromJson(row);
    final descriptions = {1: 'Sehr hart', 2: 'Hart', 3: 'Normal', 4: 'Weich', 5: 'Flüssig'};
    entries.add(DiaryEntry(
      id: toilet.id,
      type: DiaryEntryType.toilet,
      trackedAt: toilet.trackedAt,
      title: 'Toilettengang',
      subtitle: descriptions[toilet.stoolType] ?? 'Normal',
      data: toilet,
    ));
  }

  for (final row in results[2] as List) {
    final gut = GutFeelingEntry.fromJson(row);
    final rating = calculateGutFeelingRating(gut);
    entries.add(DiaryEntry(
      id: gut.id,
      type: DiaryEntryType.gutFeeling,
      trackedAt: gut.trackedAt,
      title: 'Bauchgefühl',
      subtitle: rating.level.label,
      data: gut,
    ));
  }

  for (final row in results[3] as List) {
    final drink = DrinkEntry.fromDbRow(row);
    entries.add(DiaryEntry(
      id: drink.id,
      type: DiaryEntryType.drink,
      trackedAt: drink.trackedAt,
      title: drink.drinkName,
      subtitle: '${drink.amountMl} ml',
      data: drink,
    ));
  }

  entries.sort((a, b) => b.trackedAt.compareTo(a.trackedAt));
  return entries;
});

/// Delete an entry by type and ID
Future<void> deleteEntry(DiaryEntryType type, String id) async {
  final table = switch (type) {
    DiaryEntryType.meal => 'meal_entries',
    DiaryEntryType.toilet => 'toilet_entries',
    DiaryEntryType.gutFeeling => 'gut_feeling_entries',
    DiaryEntryType.drink => 'drink_entries',
  };
  await SupabaseService.client.from(table).delete().eq('id', id);
}
