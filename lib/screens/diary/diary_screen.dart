import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/diary_provider.dart';
import '../../services/haptic_service.dart';
import '../../widgets/common/bb_card.dart';
import '../../widgets/common/mascot_image.dart';
import 'widgets/diary_detail_sheets.dart';

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(diaryDateProvider);
    final entriesAsync = ref.watch(diaryEntriesProvider(date));
    final dateFormat = DateFormat('d. MMMM yyyy', 'de_DE');
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
                ref.read(diaryDateProvider.notifier).state =
                    DateTime(now.year, now.month, now.day);
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
                      ref.read(diaryDateProvider.notifier).state =
                          date.subtract(const Duration(days: 1));
                    },
                  ),
                  Text(
                    dateFormat.format(date),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: isToday
                        ? null
                        : () {
                            HapticService.light();
                            ref.read(diaryDateProvider.notifier).state =
                                date.add(const Duration(days: 1));
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
                            'Keine Einträge',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tracke deine erste Mahlzeit!',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.mutedForeground,
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
                      return _DiaryEntryCard(
                        entry: entry,
                        onTap: () => showDiaryDetailSheet(context, ref, entry),
                        onDismissed: () async {
                          await deleteEntry(entry.type, entry.id);
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

class _DiaryEntryCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _DiaryEntryCard({
    required this.entry,
    required this.onTap,
    required this.onDismissed,
  });

  IconData get _icon => switch (entry.type) {
        DiaryEntryType.meal => Icons.restaurant,
        DiaryEntryType.toilet => Icons.wc,
        DiaryEntryType.gutFeeling => Icons.favorite,
        DiaryEntryType.drink => Icons.local_drink,
      };

  Color get _color => switch (entry.type) {
        DiaryEntryType.meal => AppTheme.primary,
        DiaryEntryType.toilet => AppTheme.info,
        DiaryEntryType.gutFeeling => AppTheme.warning,
        DiaryEntryType.drink => AppTheme.success,
      };

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm', 'de_DE');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(entry.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          HapticService.medium();
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Eintrag löschen?'),
              content: const Text('Möchtest du diesen Eintrag wirklich löschen?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Abbrechen'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.destructive),
                  child: const Text('Löschen'),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) => onDismissed(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppTheme.destructive,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: GestureDetector(
          onTap: onTap,
          child: BbCard(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, color: _color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foreground,
                        ),
                      ),
                      Text(
                        entry.subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  timeFormat.format(entry.trackedAt),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
