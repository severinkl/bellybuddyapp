import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/constants.dart';
import '../../../../providers/drink_tracker_provider.dart';
import '../../../../utils/date_format_utils.dart';
import '../../../../utils/drink_helpers.dart';
import 'glass_meter.dart';

/// „Heute getrunken" (or „Am 26.11. getrunken"): the day's total including
/// the entry being made („+ 400 ml"), and one glass per 250 ml. No goal.
class DrinkTodayCard extends ConsumerWidget {
  const DrinkTodayCard({super.key});

  static const totalKey = Key('drink_today_total');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackedAt = ref.watch(
      drinkTrackerProvider.select((s) => s.trackedAt),
    );
    final dayTotal = ref.watch(drinkTrackerProvider.select((s) => s.dayTotal));
    final pending = ref.watch(
      drinkTrackerProvider.select(
        (s) => s.selectedDrink != null ? (s.selectedAmount ?? 0) : 0,
      ),
    );

    final label = isSameDay(trackedAt, DateTime.now())
        ? 'Heute getrunken'
        : 'Am ${formatDayMonth(trackedAt)} getrunken';
    final total = DrinkHelpers.formatAmount(dayTotal + pending);
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) >=
        AppConstants.drinkGridLargeTextScale;

    final labelText = Text(
      label,
      style: const TextStyle(
        fontSize: AppTheme.fontSizeCaptionLG,
        fontWeight: FontWeight.w500,
        color: AppTheme.mutedForeground,
      ),
    );
    final totalRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (pending > 0) ...[
          Text(
            '+ ${DrinkHelpers.formatAmount(pending)}',
            style: const TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: FontWeight.w600,
              color: AppTheme.infoText,
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
        ],
        Text(
          total,
          key: totalKey,
          style: const TextStyle(
            fontSize: AppTheme.fontSizeHeadingLG,
            fontWeight: FontWeight.w700,
            color: AppTheme.foreground,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacing20,
        vertical: AppConstants.spacing14,
      ),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // One header node: the label, the shown total as its value.
          Semantics(
            container: true,
            header: true,
            label: label,
            value: total,
            excludeSemantics: true,
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [labelText, totalRow],
                  )
                : Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [labelText, totalRow],
                  ),
          ),
          AppConstants.gap10,
          GlassMeter(drunkMl: dayTotal, pendingMl: pending),
        ],
      ),
    );
  }
}
