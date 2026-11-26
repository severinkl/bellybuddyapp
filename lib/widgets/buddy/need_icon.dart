import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../services/buddy/daily_care.dart';
import '../../utils/gut_feeling_rating.dart';
import '../../utils/logger.dart';

/// A need's sticker icon (decorative: no semantics), drawn at [size] ×
/// [size], or, without a size, filling the square box it is laid out in (a
/// [NeedMeter]'s).
class NeedIcon extends StatelessWidget {
  const NeedIcon(this.need, {super.key, this.size, this.gutFeeling});

  final CareNeed need;
  final double? size;

  /// Bauchgefühl only: the mouth of how the belly felt; null (or any other
  /// need) draws the plain icon.
  final GutFeelingRatingLevel? gutFeeling;

  static const _log = AppLogger('NeedIcon');
  static const _dir = 'assets/images/icons/needs';

  /// The asset that draws [need]; for Bauchgefühl, the belly with
  /// [gutFeeling]'s mouth (the plain smile when null or „Gut").
  static String assetFor(CareNeed need, {GutFeelingRatingLevel? gutFeeling}) =>
      switch (need) {
        CareNeed.food => '$_dir/food.svg',
        CareNeed.drink => '$_dir/drink.svg',
        CareNeed.toilet => '$_dir/toilet.svg',
        CareNeed.gutFeeling => switch (gutFeeling) {
          GutFeelingRatingLevel.spiGut => '$_dir/gut_feeling_sehr_gut.svg',
          GutFeelingRatingLevel.mittel => '$_dir/gut_feeling_mittel.svg',
          GutFeelingRatingLevel.schlecht => '$_dir/gut_feeling_schlecht.svg',
          GutFeelingRatingLevel.gut || null => '$_dir/gut_feeling.svg',
        },
      };

  /// Every asset path ([assetFor] over every need and level).
  static final List<String> assets = {
    for (final need in CareNeed.values)
      for (final level in [null, ...GutFeelingRatingLevel.values])
        assetFor(need, gutFeeling: level),
  }.toList(growable: false);

  /// Loads and compiles all of [assets] into flutter_svg's cache, under the
  /// key [SvgPicture.asset] uses with the root bundle and the default
  /// theme, so no icon pops in late. Never throws: a failure is logged, and
  /// the icons then load as they are drawn.
  static Future<void> precache() async {
    try {
      await Future.wait(assets.map((a) => SvgAssetLoader(a).loadBytes(null)));
    } catch (e) {
      _log.warn('precache failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    assetFor(need, gutFeeling: gutFeeling),
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}
