import 'package:freezed_annotation/freezed_annotation.dart';
import 'fodmap_flags.dart';

part 'drink.freezed.dart';
part 'drink.g.dart';

@freezed
abstract class Drink with _$Drink {
  const factory Drink({
    required String id,
    required String name,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(FodmapFlags())
    FodmapFlags fodmaps,
    @JsonKey(name: 'added_by_user_id') String? addedByUserId,
  }) = _Drink;

  const Drink._();

  factory Drink.fromJson(Map<String, dynamic> json) => _$DrinkFromJson(json);

  /// Create from database row which has fodmap_ prefixed columns
  factory Drink.fromDbRow(Map<String, dynamic> row) {
    return Drink(
      id: row['id'] as String,
      name: row['name'] as String,
      fodmaps: FodmapFlags.fromDbRow(row),
      addedByUserId: row['added_by_user_id'] as String?,
    );
  }
}
