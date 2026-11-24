import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../models/insights.dart';
import '../../../services/insights/insight_copy.dart';
import '../../../widgets/common/bb_card.dart';

/// „Fällt mir auf": a row per item, the „noch unsicher" ones last with
/// their badge; or that nothing stands out yet.
class NoticedList extends StatelessWidget {
  const NoticedList({super.key, required this.noticed});

  /// [Insights.noticed].
  final List<Noticed> noticed;

  @override
  Widget build(BuildContext context) {
    return BbCard(
      child: noticed.isEmpty
          ? const Text(InsightCopy.nothingYet, style: AppTheme.bodyMutedStyle)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppConstants.spacing12,
              children: [for (final n in noticed) _NoticedRow(n)],
            ),
    );
  }
}

/// „Zwiebel · an 4 von 5 schweren Tagen dabei · an guten Tagen: 1 von 6",
/// read with its badge when uncertain.
class _NoticedRow extends StatelessWidget {
  const _NoticedRow(this.noticed);

  final Noticed noticed;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      InsightCopy.noticedRow(noticed),
      style: noticed.uncertain ? AppTheme.bodyMutedStyle : AppTheme.bodyStyle,
    );
    if (!noticed.uncertain) return text;
    return MergeSemantics(
      child: Wrap(
        spacing: AppConstants.spacingSm,
        runSpacing: AppConstants.spacingXs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [text, const _UncertainBadge()],
      ),
    );
  }
}

/// „noch unsicher".
class _UncertainBadge extends StatelessWidget {
  const _UncertainBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacing2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.muted,
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: const Text(
        InsightCopy.uncertain,
        style: TextStyle(
          fontSize: AppTheme.fontSizeCaption,
          fontWeight: FontWeight.w600,
          color: AppTheme.foreground,
        ),
      ),
    );
  }
}
