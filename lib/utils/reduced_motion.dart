import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';

/// The user's "reduce motion" setting (iOS Reduce Motion, Android
/// "Remove animations"), as Flutter reports it.
abstract final class ReducedMotion {
  /// Whether animations should be skipped.
  static bool of(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], or [Duration.zero] when motion is reduced.
  static Duration duration(BuildContext context, Duration d) =>
      of(context) ? Duration.zero : d;

  /// A shimmering placeholder, or the static [baseColor] behind [child] when
  /// motion is reduced.
  static Widget shimmer(
    BuildContext context, {
    required Color baseColor,
    required Color highlightColor,
    required Widget child,
  }) => of(context)
      ? ColoredBox(color: baseColor, child: child)
      : Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: child,
        );
}
