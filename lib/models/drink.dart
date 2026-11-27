import 'package:freezed_annotation/freezed_annotation.dart';
import 'drink_icon.dart';
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

    /// Other names the drink is found under in the search.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<String>[])
    List<String> synonyms,

    /// The icon of the drink's first category; null: the name decides.
    @JsonKey(includeFromJson: false, includeToJson: false)
    DrinkIcon? categoryIcon,
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
      synonyms: _synonyms(row['drink_synonyms']),
      categoryIcon: _categoryIcon(row['drink_categories']),
    );
  }

  /// The `drink_synonyms(name)` embed. Absent in a row without it (the
  /// parser tolerates that), but an older server answers the embedding
  /// request itself with PGRST200: the app requires core 0025/0026 to be
  /// deployed first.
  static List<String> _synonyms(Object? embed) => [
    if (embed is List)
      for (final s in embed)
        if (s is Map && s['name'] is String) s['name'] as String,
  ];

  static final _iconsByName = DrinkIcon.values.asNameMap();

  /// The icon of the category with the lowest position that has a known icon.
  static DrinkIcon? _categoryIcon(Object? embed) {
    if (embed is! List) return null;
    final found = <(int, DrinkIcon)>[];
    for (final link in embed) {
      final cat = link is Map ? link['catalog_categories'] : null;
      if (cat is! Map) continue;
      final icon = _iconsByName[cat['drink_icon']];
      if (icon == null) continue;
      found.add(((cat['position'] as num?)?.toInt() ?? 1 << 30, icon));
    }
    if (found.isEmpty) return null;
    found.sort((a, b) => a.$1.compareTo(b.$1));
    return found.first.$2;
  }
}
