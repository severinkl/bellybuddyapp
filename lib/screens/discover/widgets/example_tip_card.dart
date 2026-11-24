import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../widgets/common/bb_card.dart';
import '../../../widgets/common/dashed_border_painter.dart';

/// A made-up tip shown above the weekly-tips opt-in, so people see what they
/// would get. Dashed and labelled „Beispiel", so it never passes for one of
/// their own tips.
class ExampleTipCard extends StatelessWidget {
  const ExampleTipCard({super.key});

  static const cardKey = Key('discover_example_tip');

  static const label = 'Beispiel';
  static const lead = 'So sieht ein Tipp aus';
  static const title = 'Zwiebel mal tauschen?';
  static const body =
      'Diese Woche war in 3 Mahlzeiten Zwiebel. Magst du mal das Grüne von '
      'Frühlingszwiebeln probieren? Danach siehst du an deinem Bauchgefühl, '
      'wie es dir damit geht.';
  static const footer = 'Ausgedachtes Beispiel, nicht aus deinen Einträgen.';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: cardKey,
      container: true,
      excludeSemantics: true,
      // The title ends with its own „?".
      label: 'Beispiel-Tipp: $title $body $footer',
      child: CustomPaint(
        foregroundPainter: const DashedBorderPainter(),
        child: BbCard(
          color: AppTheme.background,
          showBorder: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingSm,
                      vertical: AppConstants.spacingXs,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSm,
                      ),
                    ),
                    child: Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeCaption,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  const Flexible(
                    child: Text(lead, style: AppTheme.captionMutedStyle),
                  ),
                ],
              ),
              AppConstants.gap8,
              const Text(
                title,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeSubtitleLG,
                  fontWeight: FontWeight.w700,
                ),
              ),
              AppConstants.gap6,
              const Text(
                body,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBodyLG,
                  height: AppTheme.lineHeightBody,
                ),
              ),
              AppConstants.gap8,
              const Text(footer, style: AppTheme.captionMutedStyle),
            ],
          ),
        ),
      ),
    );
  }
}
