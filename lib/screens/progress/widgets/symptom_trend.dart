import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/progress.dart';
import '../../../services/progress/progress_copy.dart';

/// „Beschwerden pro Woche": a row per gut symptom, one bar per week, oldest
/// left, newest right; a week without means is a hollow marker.
class SymptomTrend extends StatelessWidget {
  const SymptomTrend({super.key, required this.weeks});

  /// Oldest first, the last the current week.
  final List<ProgressWeek> weeks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: const Text(
            ProgressCopy.trendTitle,
            style: AppTheme.bodyMutedStyle,
          ),
        ),
        AppConstants.gap8,
        for (final symptom in AppConstants.gutFeelingSymptoms) ...[
          _Row(symptom: symptom, weeks: weeks),
          AppConstants.gap12,
        ],
        const Text(
          ProgressCopy.trendCaption,
          style: TextStyle(
            fontSize: AppTheme.fontSizeCaption,
            height: AppTheme.lineHeightSnug,
            color: AppTheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.symptom, required this.weeks});

  final String symptom;
  final List<ProgressWeek> weeks;

  @override
  Widget build(BuildContext context) {
    final mean = ProgressCopy.trendMean(symptom);
    return Semantics(
      container: true,
      label: ProgressCopy.trendSemantics(symptom, weeks),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppConstants.spacingXs,
        children: [
          Text(
            symptom,
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          SizedBox(
            height: AppConstants.progressTrendRowHeight,
            width: double.infinity,
            child: CustomPaint(
              painter: TrendBarsPainter([
                for (final w in weeks)
                  if (w.means case final m?) mean(m) else null,
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints [values] (1–5, null = too few entries) as bars on a shared
/// baseline: height from a small stub at 1 to the full height at 5; a null
/// is a hollow circle on the baseline.
class TrendBarsPainter extends CustomPainter {
  const TrendBarsPainter(this.values);

  final List<double?> values;

  /// Bar height for a mean [v] within [height].
  static double barHeight(double v, double height) {
    const stub = AppConstants.progressTrendStubHeight;
    return stub + ((v.clamp(1, 5) - 1) / 4) * (height - stub);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const gap = AppConstants.progressTrendBarGap;
    final slot = (size.width - gap * (values.length - 1)) / values.length;
    final bar = Paint()..color = AppTheme.progressTrendBar;
    final marker = Paint()
      ..color = AppTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppConstants.progressTrendMarkerStroke;
    for (var i = 0; i < values.length; i++) {
      final left = i * (slot + gap);
      final v = values[i];
      if (v == null) {
        const r = AppConstants.progressTrendMarkerSize / 2;
        canvas.drawCircle(
          Offset(left + slot / 2, size.height - r),
          r - AppConstants.progressTrendMarkerStroke / 2,
          marker,
        );
      } else {
        final h = barHeight(v, size.height);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(left, size.height - h, slot, h),
            topLeft: const Radius.circular(AppConstants.radiusXs / 2),
            topRight: const Radius.circular(AppConstants.radiusXs / 2),
          ),
          bar,
        );
      }
    }
  }

  @override
  bool shouldRepaint(TrendBarsPainter old) => !listEquals(old.values, values);
}
