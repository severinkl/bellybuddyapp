import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/models/fodmap_flags.dart';

void main() {
  group('FodmapFlags', () {
    test('hasAny false when all false', () {
      const flags = FodmapFlags();
      expect(flags.hasAny, isFalse);
    });

    test('hasAny true when any single flag is true', () {
      expect(const FodmapFlags(fructans: true).hasAny, isTrue);
      expect(const FodmapFlags(gos: true).hasAny, isTrue);
      expect(const FodmapFlags(lactose: true).hasAny, isTrue);
      expect(const FodmapFlags(fructose: true).hasAny, isTrue);
      expect(const FodmapFlags(sorbitol: true).hasAny, isTrue);
      expect(const FodmapFlags(mannitol: true).hasAny, isTrue);
    });

    test('warnings returns correct German labels for each flag', () {
      const flags = FodmapFlags(
        fructans: true,
        gos: true,
        lactose: true,
        fructose: true,
        sorbitol: true,
        mannitol: true,
      );
      expect(flags.warnings, [
        'Fruktane',
        'GOS',
        'Laktose',
        'Fruktose',
        'Sorbit',
        'Mannit',
      ]);
    });

    test('warnings empty when no flags set', () {
      const flags = FodmapFlags();
      expect(flags.warnings, isEmpty);
    });

    test('fromDbRow with all fodmap columns present', () {
      final flags = FodmapFlags.fromDbRow({
        'fodmap_fructans': true,
        'fodmap_gos': false,
        'fodmap_lactose': true,
        'fodmap_fructose': false,
        'fodmap_sorbitol': true,
        'fodmap_mannitol': false,
      });
      expect(flags.fructans, isTrue);
      expect(flags.gos, isFalse);
      expect(flags.lactose, isTrue);
      expect(flags.fructose, isFalse);
      expect(flags.sorbitol, isTrue);
      expect(flags.mannitol, isFalse);
    });

    test('fromDbRow with missing columns defaults to false', () {
      final flags = FodmapFlags.fromDbRow(<String, dynamic>{});
      expect(flags.hasAny, isFalse);
    });

    test('fromDbRow with null values defaults to false', () {
      final flags = FodmapFlags.fromDbRow({
        'fodmap_fructans': null,
        'fodmap_gos': null,
        'fodmap_lactose': null,
        'fodmap_fructose': null,
        'fodmap_sorbitol': null,
        'fodmap_mannitol': null,
      });
      expect(flags.hasAny, isFalse);
    });
  });
}
