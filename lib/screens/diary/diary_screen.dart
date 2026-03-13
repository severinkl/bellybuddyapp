import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/diary_provider.dart';
import '../../providers/entries_provider.dart';
import '../../router/route_names.dart';
import '../../services/haptic_service.dart';
import '../../widgets/common/bb_button.dart';
import '../../widgets/common/mascot_image.dart';
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
      appBar: AppBar(
        title: const Text('Tagebuch'),
        actions: [
          if (!isToday)
            TextButton(
              onPressed: () {
                HapticService.light();
                final now = DateTime.now();
                ref.read(diaryDateProvider.notifier).set(
                    DateTime(now.year, now.month, now.day));
              },
              child: const Text('Heute'),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async => ref.invalidate(diaryEntriesProvider(date)),
        child: Column(
          children: [
            // Date navigation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      HapticService.light();
                      ref.read(diaryDateProvider.notifier).set(
                          date.subtract(const Duration(days: 1)));
                    },
                  ),
                  GestureDetector(
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
                        Text(
                          formatDateLong(date),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: isToday
                        ? null
                        : () {
                            HapticService.light();
                            ref.read(diaryDateProvider.notifier).set(
                                date.add(const Duration(days: 1)));
                          },
                  ),
                ],
              ),
            ),
            // Entries list
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
                          MascotImage(
                            assetPath: AppConstants.mascotClueless,
                            width: 120,
                            height: 120,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Bereit zum Tracken?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isToday
                                ? 'Noch keine Daten für heute.'
                                : 'Keine Daten für diesen Tag.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 48),
                            child: Column(
                              children: [
                                BbButton(
                                  label: 'Bauchgefühl tracken',
                                  icon: Icons.favorite,
                                  onPressed: () =>
                                      context.push(RoutePaths.gutFeelingTracker),
                                ),
                                const SizedBox(height: 12),
                                BbButton(
                                  label: 'Toilettengang tracken',
                                  icon: Icons.wc,
                                  isOutlined: true,
                                  onPressed: () =>
                                      context.push(RoutePaths.toiletTracker),
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
                          await ref.read(entriesProvider.notifier).deleteByType(entry.type.name, entry.id);
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
