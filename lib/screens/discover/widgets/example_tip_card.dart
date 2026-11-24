import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';

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
      label: 'Beispiel-Tipp: $title. $body $footer',
      child: CustomPaint(
        painter: const _DashedBorderPainter(),
        child: Container(
          padding: AppConstants.paddingMd,
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          ),
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

/// Strokes the rounded rect's outline as dashes.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const inset = AppConstants.borderWidthLg / 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            inset,
            inset,
            size.width - 2 * inset,
            size.height - 2 * inset,
          ),
          const Radius.circular(AppConstants.radiusLg),
        ),
      );
    final paint = Paint()
      ..color = AppTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppConstants.borderWidthLg;
    for (final PathMetric metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, d + AppConstants.dashLength),
          paint,
        );
        d += AppConstants.dashLength + AppConstants.dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => false;
}
