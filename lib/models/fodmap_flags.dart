import 'package:freezed_annotation/freezed_annotation.dart';

part 'fodmap_flags.freezed.dart';
part 'fodmap_flags.g.dart';

@freezed
abstract class FodmapFlags with _$FodmapFlags {
  const factory FodmapFlags({
    @Default(false) bool fructans,
    @Default(false) bool gos,
    @Default(false) bool lactose,
    @Default(false) bool fructose,
    @Default(false) bool sorbitol,
    @Default(false) bool mannitol,
  }) = _FodmapFlags;

  const FodmapFlags._();

  /// The FODMAP keys: the catalog's `fodmap_*` columns without the prefix.
  static const keys = {
    'fructans',
    'gos',
    'lactose',
    'fructose',
    'sorbitol',
    'mannitol',
  };

  factory FodmapFlags.fromJson(Map<String, dynamic> json) =>
      _$FodmapFlagsFromJson(json);

  bool get hasAny =>
      fructans || gos || lactose || fructose || sorbitol || mannitol;

  /// Whether the flag named by FODMAP [key] (see [keys]) is set; false for an
  /// unknown key.
  bool has(String key) => switch (key) {
    'fructans' => fructans,
    'gos' => gos,
    'lactose' => lactose,
    'fructose' => fructose,
    'sorbitol' => sorbitol,
    'mannitol' => mannitol,
    _ => false,
  };

  List<String> get warnings {
    final result = <String>[];
    if (fructans) result.add('Fruktane');
    if (gos) result.add('GOS');
    if (lactose) result.add('Laktose');
    if (fructose) result.add('Fruktose');
    if (sorbitol) result.add('Sorbit');
    if (mannitol) result.add('Mannit');
    return result;
  }

  /// Create from database row with fodmap_ prefixed columns
  factory FodmapFlags.fromDbRow(Map<String, dynamic> row) {
    return FodmapFlags(
      fructans: row['fodmap_fructans'] as bool? ?? false,
      gos: row['fodmap_gos'] as bool? ?? false,
      lactose: row['fodmap_lactose'] as bool? ?? false,
      fructose: row['fodmap_fructose'] as bool? ?? false,
      sorbitol: row['fodmap_sorbitol'] as bool? ?? false,
      mannitol: row['fodmap_mannitol'] as bool? ?? false,
    );
  }
}
