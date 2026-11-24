import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/bb_card.dart';

/// A white card of a recipe page („Zutaten", „Zubereitung") with a heading
/// and, at its right, a [trailing] (e.g. „für 2 Portionen" in
/// [captionStyle]).
class RecipeSectionCard extends StatelessWidget {
  const RecipeSectionCard({
    super.key,
    required this.title,
    this.trailing,
    required this.children,
  });

  /// The muted style of a [trailing] text.
  static const captionStyle = TextStyle(
    fontSize: AppTheme.fontSizeCaptionLG,
    color: AppTheme.mutedForeground,
  );

  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return BbCard(
      color: Colors.white,
      showBorder: false,
      radius: AppConstants.radiusRound,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppConstants.spacingSm,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeTitle,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foreground,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          AppConstants.gap8,
          ...children,
        ],
      ),
    );
  }
}

/// „35 Min · 2 Portionen" behind a clock.
class RecipeMetaLine extends StatelessWidget {
  const RecipeMetaLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.schedule,
          size: AppConstants.iconSizeSm,
          color: AppTheme.mutedForeground,
        ),
        const SizedBox(width: AppConstants.spacing6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBodyLG,
              color: AppTheme.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}

/// A muted line naming where a recipe comes from: [lead], the underlined
/// [name], [tail], and „ ›" when [onTap] opens it („Quelle: Reizdarmblog ›").
/// Without [onTap] it is plain text. Screen readers hear it without the
/// „›", as a link when it is one.
class RecipeLinkLine extends StatelessWidget {
  const RecipeLinkLine({
    super.key,
    required this.lead,
    required this.name,
    this.tail = '',
    this.onTap,
  });

  final String lead, name, tail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final link = onTap != null;
    final text = Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: AppTheme.fontSizeBody,
          color: AppTheme.mutedForeground,
        ),
        children: [
          TextSpan(text: lead),
          TextSpan(
            text: name,
            style: TextStyle(
              color: AppTheme.foreground,
              fontWeight: FontWeight.w500,
              decoration: link ? TextDecoration.underline : null,
              decorationColor: AppTheme.border,
            ),
          ),
          TextSpan(text: tail),
          if (link) const TextSpan(text: ' ›'),
        ],
      ),
      semanticsLabel: '$lead$name$tail',
    );
    if (!link) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXs),
        child: text,
      );
    }
    return Semantics(
      link: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingXs,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              child: text,
            ),
          ),
        ),
      ),
    );
  }
}
