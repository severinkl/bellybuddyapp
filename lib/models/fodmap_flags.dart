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

  factory FodmapFlags.fromJson(Map<String, dynamic> json) =>
      _$FodmapFlagsFromJson(json);

  bool get hasAny =>
      fructans || gos || lactose || fructose || sorbitol || mannitol;

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
