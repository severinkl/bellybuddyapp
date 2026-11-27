import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../services/daily_review/daily_review_copy.dart';

/// The quiet line after a meal: which of its ingredients could trouble the
/// belly, with a link to the Alternativen. Free; the Alternativen gate
/// themselves.
class FlaggedIngredientsLine extends StatelessWidget {
  const FlaggedIngredientsLine({
    super.key,
    required this.names,
    required this.onOpen,
    this.centered = false,
  });

  /// The flagged ingredients' names, in the order they are named.
  final List<String> names;

  /// Opens the Alternativen.
  final VoidCallback onOpen;

  /// Centres the line (the success screen); else it starts left (the diary).
  final bool centered;

  static const openKey = Key('flagged_ingredients_open');

  /// „Zwiebel könnte …", „Zwiebel und Knoblauch könnten …", „Zwiebel,
  /// Knoblauch und 2 weitere könnten deinem Bauch zu schaffen machen."
  static String text(List<String> names) {
    const rest = 'deinem Bauch zu schaffen machen.';
    return switch (names) {
      [final one] => '$one könnte $rest',
      [final a, final b] => '$a und $b könnten $rest',
      [final a, final b, ...final more] =>
        '$a, $b und ${more.length} weitere könnten $rest',
      [] => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          text(names),
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            fontSize: AppTheme.fontSizeBody,
            color: AppTheme.mutedForeground,
          ),
        ),
        TextButton(
          key: openKey,
          onPressed: onOpen,
          style: TextButton.styleFrom(foregroundColor: AppTheme.foreground),
          child: const Text(DailyReviewCopy.viewAlternatives),
        ),
      ],
    );
  }
}
