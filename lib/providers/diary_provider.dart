import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diary_entry.dart';
import '../services/entry_query_service.dart';
import '../services/supabase_service.dart';
import '../utils/diary_helpers.dart';
import '../utils/logger.dart';

export '../models/diary_entry.dart';

const _log = AppLogger('DiaryProvider');

/// Selected date for the diary view
class _DiaryDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void set(DateTime date) => state = date;
}

final diaryDateProvider = NotifierProvider<_DiaryDateNotifier, DateTime>(
  _DiaryDateNotifier.new,
);

/// Fetches and merges all entry types for the selected date
final diaryEntriesProvider = FutureProvider.family<List<DiaryEntry>, DateTime>((
  ref,
  date,
) async {
  final userId = SupabaseService.userId;
  if (userId == null) return [];

  try {
    final result = await EntryQueryService.fetchEntriesForDateRange(
      userId: userId,
      date: date,
    );

    return DiaryHelpers.buildEntries(result);
  } catch (e, st) {
    _log.error('failed to load diary entries for $date', e, st);
    rethrow;
  }
});
