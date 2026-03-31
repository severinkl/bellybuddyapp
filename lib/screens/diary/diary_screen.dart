import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/diary_provider.dart';
import '../../widgets/common/bb_async_state.dart';
import '../../widgets/common/circle_icon_button.dart';
import '../../providers/entries_provider.dart';
import '../../router/route_names.dart';
import '../../services/haptic_service.dart';
import '../../widgets/common/tracker_card.dart';
import 'widgets/diary_detail_sheets.dart';
import '../../utils/date_format_utils.dart';
import 'widgets/diary_entry_card.dart';

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  static const displayedDateKey = Key('diary_displayed_date');
  static const previousDayKey = Key('diary_previous_day');
  static const nextDayKey = Key('diary_next_day');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(diaryDateProvider);
    final entriesAsync = ref.watch(diaryEntriesProvider(date));
    final isToday = isSameDay(date, DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleIconButton(
              tapKey: DiaryScreen.previousDayKey,
              icon: Icons.chevron_left,
              onPressed: () {
                HapticService.light();
                ref
                    .read(diaryDateProvider.notifier)
                    .set(date.subtract(const Duration(days: 1)));
              },
            ),
            Flexible(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    locale: const Locale('de', 'DE'),
                  );
                  if (picked != null) {
                    HapticService.light();
                    ref.read(diaryDateProvider.notifier).set(picked);
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: AppTheme.mutedForeground,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        key: DiaryScreen.displayedDateKey,
                        formatDateWeekday(date),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTheme.fontSizeSubtitle,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isToday)
              const SizedBox(width: 44)
            else
              CircleIconButton(
                tapKey: DiaryScreen.nextDayKey,
                icon: Icons.chevron_right,
                onPressed: () {
                  HapticService.light();
                  ref
                      .read(diaryDateProvider.notifier)
                      .set(date.add(const Duration(days: 1)));
                },
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async => ref.invalidate(diaryEntriesProvider(date)),
        child: Column(
          children: [
            Expanded(
              child: entriesAsync.when(
                loading: () =>
                    const BbLoadingState(message: 'Einträge laden...'),
                error: (e, _) => const BbErrorState(
                  message: 'Fehler beim Laden der Einträge.',
                ),
                data: (entries) {
                  if (entries.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isToday
                                ? 'Noch keine Daten für heute.'
                                : 'Keine Daten für diesen Tag.',
                            style: const TextStyle(
                              fontSize: AppTheme.fontSizeTitleLG,
                              color: AppTheme.mutedForeground,
                            ),
                          ),
                          AppConstants.gap4,
                          const Text(
                            'Bereit zum Tracken?',
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeHeadingLG,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.foreground,
                            ),
                          ),
                          AppConstants.gap24,
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TrackerCard(
                                    svgPath: AppConstants.logoSvg,
                                    label: 'Bauchgefühl',
                                    onTap: () => context.push(
                                      RoutePaths.gutFeelingTracker,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TrackerCard(
                                    svgPath: AppConstants.toiletPaperSvg,
                                    label: 'Klo',
                                    onTap: () =>
                                        context.push(RoutePaths.toiletTracker),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: AppConstants.paddingMd,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return DiaryEntryCard(
                        entry: entry,
                        onTap: () => showDiaryDetailSheet(context, ref, entry),
                        onDismissed: () async {
                          await ref
                              .read(entriesProvider.notifier)
                              .deleteByType(entry.type.name, entry.id);
                          ref.invalidate(diaryEntriesProvider(date));
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
