import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/diary_provider.dart';
import '../../../providers/entries_provider.dart';
import '../../../router/route_names.dart';
import '../../../services/buddy/daily_care.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/drink_helpers.dart';
import '../../../utils/gut_feeling_rating.dart';
import 'buddy_hero.dart';

/// One row of the dashboard's „Heute" list.
class TodayLogItem {
  const TodayLogItem(this.at, this.need, this.label);

  /// Local time of the entry.
  final DateTime at;

  /// The tracker the entry belongs to.
  final CareNeed need;
  final String label;
}

/// Today's (local) entries of [s], oldest first, each with a short label.
List<TodayLogItem> todayLogItems(EntriesState s, DateTime now) {
  bool isToday(DateTime trackedAt) => isSameDay(trackedAt.toLocal(), now);

  return <TodayLogItem>[
    for (final e in s.meals)
      if (isToday(e.trackedAt))
        TodayLogItem(
          e.trackedAt.toLocal(),
          CareNeed.food,
          e.title.trim().isEmpty ? 'Mahlzeit' : e.title.trim(),
        ),
    for (final e in s.drinks)
      if (isToday(e.trackedAt))
        TodayLogItem(
          e.trackedAt.toLocal(),
          CareNeed.drink,
          '${e.drinkName} · ${DrinkHelpers.formatAmount(e.amountMl)}',
        ),
    for (final e in s.gutFeelings)
      if (isToday(e.trackedAt))
        TodayLogItem(
          e.trackedAt.toLocal(),
          CareNeed.gutFeeling,
          'Bauchgefühl: ${calculateGutFeelingRating(e).level.label}',
        ),
    for (final e in s.toiletEntries)
      if (isToday(e.trackedAt))
        TodayLogItem(e.trackedAt.toLocal(), CareNeed.toilet, 'Klo-Eintrag'),
  ]..sort((a, b) => a.at.compareTo(b.at));
}

/// The dashboard's „Heute" list: today's latest entries (at most
/// [AppConstants.todayListMaxItems], oldest of them first) and a link to the
/// whole day in the diary.
class TodayList extends ConsumerWidget {
  const TodayList({super.key});

  static const diaryLinkKey = Key('today_list_diary_link');
  static const emptyText = 'Noch kein Eintrag heute.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(buddyClockProvider)();
    final all = todayLogItems(ref.watch(entriesProvider), now);
    final shown = all.length > AppConstants.todayListMaxItems
        ? all.sublist(all.length - AppConstants.todayListMaxItems)
        : all;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(
            left: AppConstants.spacingXs,
            bottom: AppConstants.spacingSm,
          ),
          child: Text(
            'Heute',
            style: TextStyle(
              fontSize: AppTheme.fontSizeTitle,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
        ),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppConstants.spacingXs,
              vertical: AppConstants.spacingSm,
            ),
            child: Text(
              emptyText,
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                color: AppTheme.mutedForeground,
              ),
            ),
          )
        else
          for (final item in shown) ...[
            _TodayRow(item: item),
            if (item != shown.last)
              const SizedBox(height: AppConstants.spacing6),
          ],
        Align(
          child: TextButton(
            key: diaryLinkKey,
            onPressed: () {
              ref.read(diaryDateProvider.notifier).set(startOfDay(now));
              context.go(RoutePaths.diary);
            },
            child: const Text(
              'Ganzen Tag im Tagebuch ansehen →',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBodyLG,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.item});

  final TodayLogItem item;

  @override
  Widget build(BuildContext context) {
    final time = formatTime(item.at);
    return Semantics(
      label: '$time Uhr, ${item.label}',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: AppConstants.todayRowHeight,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing12,
          vertical: AppConstants.spacingSm,
        ),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        child: Row(
          children: [
            // At least this wide so the rows line up; wider with large
            // text instead of wrapping the time.
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: AppConstants.todayRowTimeWidth,
              ),
              child: Text(
                time,
                softWrap: false,
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeCaptionLG,
                  color: AppTheme.mutedForeground,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacingXs),
            Text(
              item.need.emoji,
              style: const TextStyle(fontSize: AppTheme.fontSizeBodyLG),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: AppTheme.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
