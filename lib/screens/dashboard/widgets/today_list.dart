import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../providers/diary_provider.dart';
import '../../../providers/entries_provider.dart';
import '../../../router/route_names.dart';
import '../../../services/buddy/buddy_mood_logic.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/gut_feeling_rating.dart';
import 'buddy_hero.dart';

/// One row of the dashboard's „Heute" list.
class TodayLogItem {
  const TodayLogItem(this.at, this.kind, this.label);

  /// Local time of the entry.
  final DateTime at;
  final EntryKind kind;
  final String label;

  String get icon => switch (kind) {
    EntryKind.meal => '🍽',
    EntryKind.drink => '💧',
    EntryKind.gutFeeling => '🙂',
    EntryKind.toilet => '🧻',
  };
}

/// "250 ml" below a litre, "1,5 l" from a litre on.
String _amount(int ml) {
  if (ml < 1000) return '$ml ml';
  final litres = ml / 1000;
  final text = litres == litres.roundToDouble()
      ? litres.toStringAsFixed(0)
      : litres.toStringAsFixed(1).replaceAll('.', ',');
  return '$text l';
}

/// Today's (local) entries of [s], oldest first, each with a short label.
List<TodayLogItem> todayLogItems(EntriesState s, DateTime now) {
  bool isToday(DateTime l) =>
      l.year == now.year && l.month == now.month && l.day == now.day;

  final items = <TodayLogItem>[
    for (final e in s.meals)
      TodayLogItem(
        e.trackedAt.toLocal(),
        EntryKind.meal,
        e.title.trim().isEmpty ? 'Mahlzeit' : e.title.trim(),
      ),
    for (final e in s.drinks)
      TodayLogItem(
        e.trackedAt.toLocal(),
        EntryKind.drink,
        '${e.drinkName} · ${_amount(e.amountMl)}',
      ),
    for (final e in s.gutFeelings)
      TodayLogItem(
        e.trackedAt.toLocal(),
        EntryKind.gutFeeling,
        'Bauchgefühl: ${calculateGutFeelingRating(e).level.label}',
      ),
    for (final e in s.toiletEntries)
      TodayLogItem(e.trackedAt.toLocal(), EntryKind.toilet, 'Klo-Eintrag'),
  ].where((i) => isToday(i.at)).toList()..sort((a, b) => a.at.compareTo(b.at));
  return items;
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
              item.icon,
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
