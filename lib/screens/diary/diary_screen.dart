import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/diary_provider.dart';
import '../../providers/entries_provider.dart';
import '../../router/route_names.dart';
import '../../services/haptic_service.dart';
import '../../widgets/common/tracker_card.dart';
import 'widgets/diary_detail_sheets.dart';
import '../../utils/date_format_utils.dart';
import 'widgets/diary_entry_card.dart';

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(diaryDateProvider);
    final entriesAsync = ref.watch(diaryEntriesProvider(date));
    final isToday = _isSameDay(date, DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CircleIconButton(
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
                        formatDateWeekday(date),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
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
              _CircleIconButton(
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
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
                error: (e, _) => Center(
                  child: Text('Fehler: $e'),
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
                              fontSize: 20,
                              color: AppTheme.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Bereit zum Tracken?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TrackerCard(
                                    svgPath: AppConstants.logoSvg,
                                    label: 'Bauchgefühl',
                                    onTap: () => context
                                        .push(RoutePaths.gutFeelingTracker),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TrackerCard(
                                    svgPath: AppConstants.toiletPaperSvg,
                                    label: 'Klo',
                                    onTap: () => context
                                        .push(RoutePaths.toiletTracker),
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
                    padding: const EdgeInsets.all(16),
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _CircleIconButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppTheme.beige,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: onPressed != null
              ? AppTheme.foreground
              : AppTheme.mutedForeground,
          size: 24,
        ),
      ),
    );
  }
}

