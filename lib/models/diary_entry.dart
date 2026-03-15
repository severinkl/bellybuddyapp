import 'drink_entry.dart';
import 'gut_feeling_entry.dart';
import 'meal_entry.dart';
import 'toilet_entry.dart';

enum DiaryEntryType { meal, toilet, gutFeeling, drink }

/// Type-safe wrapper for entry-specific data.
sealed class DiaryEntryData {
  const DiaryEntryData();
}

class MealDiaryData extends DiaryEntryData {
  final MealEntry meal;
  const MealDiaryData(this.meal);
}

class DrinkDiaryData extends DiaryEntryData {
  final DrinkEntry drink;
  const DrinkDiaryData(this.drink);
}

class GutFeelingDiaryData extends DiaryEntryData {
  final GutFeelingEntry gutFeeling;
  const GutFeelingDiaryData(this.gutFeeling);
}

class ToiletDiaryData extends DiaryEntryData {
  final ToiletEntry toilet;
  const ToiletDiaryData(this.toilet);
}

class DiaryEntry {
  final String id;
  final DiaryEntryType type;
  final DateTime trackedAt;
  final String title;
  final String subtitle;
  final DiaryEntryData data;

  const DiaryEntry({
    required this.id,
    required this.type,
    required this.trackedAt,
    required this.title,
    required this.subtitle,
    required this.data,
  });
}
