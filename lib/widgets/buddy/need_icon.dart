import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../services/buddy/daily_care.dart';
import '../../utils/gut_feeling_rating.dart';

/// A need's sticker icon (decorative: no semantics), drawn at [size] × [size].
class NeedIcon extends StatelessWidget {
  const NeedIcon(this.need, {super.key, required this.size, this.gutFeeling});

  final CareNeed need;
  final double size;

  /// Bauchgefühl only: the mouth of how the belly felt; null (or any other
  /// need) draws the plain icon.
  final GutFeelingRatingLevel? gutFeeling;

  static const _dir = 'assets/images/icons/needs';
  static const _food = '$_dir/food.svg';
  static const _drink = '$_dir/drink.svg';
  static const _toilet = '$_dir/toilet.svg';
  static const _gutFeeling = '$_dir/gut_feeling.svg';
  static const _gutFeelingSehrGut = '$_dir/gut_feeling_sehr_gut.svg';
  static const _gutFeelingMittel = '$_dir/gut_feeling_mittel.svg';
  static const _gutFeelingSchlecht = '$_dir/gut_feeling_schlecht.svg';

  /// The asset that draws [need]; for Bauchgefühl, the belly with
  /// [gutFeeling]'s mouth (the plain smile when null or „Gut").
  static String assetFor(CareNeed need, {GutFeelingRatingLevel? gutFeeling}) =>
      switch (need) {
        CareNeed.food => _food,
        CareNeed.drink => _drink,
        CareNeed.toilet => _toilet,
        CareNeed.gutFeeling => switch (gutFeeling) {
          GutFeelingRatingLevel.spiGut => _gutFeelingSehrGut,
          GutFeelingRatingLevel.mittel => _gutFeelingMittel,
          GutFeelingRatingLevel.schlecht => _gutFeelingSchlecht,
          GutFeelingRatingLevel.gut || null => _gutFeeling,
        },
      };

  /// All seven asset paths.
  static const List<String> assets = [
    _food,
    _drink,
    _toilet,
    _gutFeeling,
    _gutFeelingSehrGut,
    _gutFeelingMittel,
    _gutFeelingSchlecht,
  ];

  /// Loads and compiles all seven into flutter_svg's cache, under the key
  /// [SvgPicture.asset] uses with the root bundle and the default theme, so
  /// no icon pops in late.
  static Future<void> precache() =>
      Future.wait(assets.map((a) => SvgAssetLoader(a).loadBytes(null)));

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    assetFor(need, gutFeeling: gutFeeling),
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}
