import 'dart:io';

import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/utils/gut_feeling_rating.dart';
import 'package:belly_buddy/widgets/buddy/need_icon.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const dir = 'assets/images/icons/needs';

  test('one asset per need; Bauchgefühl per level', () {
    expect(NeedIcon.assetFor(CareNeed.food), '$dir/food.svg');
    expect(NeedIcon.assetFor(CareNeed.drink), '$dir/drink.svg');
    expect(NeedIcon.assetFor(CareNeed.toilet), '$dir/toilet.svg');
    expect(NeedIcon.assetFor(CareNeed.gutFeeling), '$dir/gut_feeling.svg');
    expect(
      NeedIcon.assetFor(
        CareNeed.gutFeeling,
        gutFeeling: GutFeelingRatingLevel.gut,
      ),
      '$dir/gut_feeling.svg',
    );
    expect(
      NeedIcon.assetFor(
        CareNeed.gutFeeling,
        gutFeeling: GutFeelingRatingLevel.spiGut,
      ),
      '$dir/gut_feeling_sehr_gut.svg',
    );
    expect(
      NeedIcon.assetFor(
        CareNeed.gutFeeling,
        gutFeeling: GutFeelingRatingLevel.mittel,
      ),
      '$dir/gut_feeling_mittel.svg',
    );
    expect(
      NeedIcon.assetFor(
        CareNeed.gutFeeling,
        gutFeeling: GutFeelingRatingLevel.schlecht,
      ),
      '$dir/gut_feeling_schlecht.svg',
    );
    expect(
      NeedIcon.assetFor(
        CareNeed.food,
        gutFeeling: GutFeelingRatingLevel.schlecht,
      ),
      '$dir/food.svg',
    );
    expect(NeedIcon.assets.toSet(), hasLength(7));
  });

  testWidgets('every icon is a plain SVG flutter_svg compiles', (tester) async {
    for (final path in NeedIcon.assets) {
      final text = File(path).readAsStringSync();
      expect(text, contains('viewBox="0 0 64 64"'), reason: path);
      for (final banned in [
        '<style',
        'class=',
        'var(',
        'filter',
        '<text',
        '<image',
      ]) {
        expect(text, isNot(contains(banned)), reason: '$path has $banned');
      }
      final bytes = await tester.runAsync(
        () => SvgAssetLoader(path).loadBytes(null),
      );
      expect(bytes!.lengthInBytes, greaterThan(0), reason: path);
    }
  });

  testWidgets('drawn at its laid-out size, decorative', (tester) async {
    await tester.pumpWidget(
      const Center(child: NeedIcon(CareNeed.drink, size: 24)),
    );

    expect(tester.getSize(find.byType(NeedIcon)), const Size(24, 24));
    final picture = tester.widget<SvgPicture>(
      find.descendant(
        of: find.byType(NeedIcon),
        matching: find.byType(SvgPicture),
      ),
    );
    expect(picture.width, 24);
    expect(picture.height, 24);
    expect(picture.excludeFromSemantics, isTrue);
  });

  testWidgets('precache fills flutter_svg\'s cache with all seven', (
    tester,
  ) async {
    svg.cache.clear();
    await tester.runAsync(NeedIcon.precache);
    expect(svg.cache.count, 7);

    // Under the keys the icons draw from: drawing all seven loads nothing new.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            for (final need in CareNeed.values) NeedIcon(need, size: 24),
            for (final level in GutFeelingRatingLevel.values)
              NeedIcon(CareNeed.gutFeeling, size: 24, gutFeeling: level),
          ],
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    expect(svg.cache.count, 7);
  });
}
