import 'package:freezed_annotation/freezed_annotation.dart';

part 'drink_entry.freezed.dart';
part 'drink_entry.g.dart';

@freezed
abstract class DrinkEntry with _$DrinkEntry {
  const factory DrinkEntry({
    required String id,
    @JsonKey(name: 'user_id') String? userId,
    @JsonKey(name: 'tracked_at') required DateTime trackedAt,
    @JsonKey(name: 'drink_id') required String drinkId,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default('Unbekanntes Getränk')
    String drinkName,
    @JsonKey(name: 'amount_ml') required int amountMl,
    String? notes,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _DrinkEntry;

  factory DrinkEntry.fromJson(Map<String, dynamic> json) =>
      _$DrinkEntryFromJson(json);

  /// Create from database row with joined drink name
  factory DrinkEntry.fromDbRow(Map<String, dynamic> row) {
    final drinks = row['drinks'] as Map<String, dynamic>?;
    return DrinkEntry(
      id: row['id'] as String,
      userId: row['user_id'] as String?,
      trackedAt: DateTime.parse(row['tracked_at'] as String),
      drinkId: row['drink_id'] as String,
      drinkName: drinks?['name'] as String? ?? 'Unbekanntes Getränk',
      amountMl: row['amount_ml'] as int,
      notes: row['notes'] as String?,
    );
  }
}
