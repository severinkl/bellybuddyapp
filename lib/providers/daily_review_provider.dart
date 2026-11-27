import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/gut_feeling_entry.dart';
import '../models/meal_entry.dart';
import '../router/route_names.dart';
import '../services/daily_review/daily_review_rules.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';
import 'alternative_choices_provider.dart';
import 'auth_provider.dart';
import 'buddy_onboarding_gate_provider.dart';
import 'diary_provider.dart';
import 'entries_provider.dart';
import 'ingredient_suggestion_provider.dart';
import 'minute_provider.dart';
import 'plus_provider.dart';
import 'profile_provider.dart';

const _log = AppLogger('DailyReview');

// Seams (spec §4.8): the subscription track gates the alternative with Plus;
// Insights v2 fills the extras.

/// Whether the review's alternative is locked (the card hides its names):
/// while Plus is locked.
final dailyReviewAlternativeLockedProvider = Provider<bool>(
  (ref) => ref.watch(plusLockedProvider),
);

/// Where „Mehr erfahren" on a locked alternative leads; null: no button.
final dailyReviewUpsellRouteProvider = Provider<String?>(
  (ref) => ref.watch(plusLockedProvider) ? RoutePaths.plus : null,
);

/// Lines of other tracks on the card (Insights v2); none yet.
final dailyReviewExtrasProvider = Provider<List<DailyReviewLine>>(
  (ref) => const [],
);

String _closedKey(String userId) =>
    '${AppConstants.keyDailyReviewClosedPrefix}$userId';

String _saidKey(String userId) =>
    '${AppConstants.keyDailyReviewSaidPrefix}$userId';

/// The day (local midnight) whose review the signed-in user closed last,
/// kept per user and device under `daily_review_closed_<userId>`
/// (yyyy-MM-dd); null while signed out or none was closed.
///
/// Preferences that can't be read or written are logged; the day then
/// lives in memory only.
class DailyReviewClosedNotifier extends AsyncNotifier<DateTime?> {
  /// The writes of this notifier instance, one after another, so an older
  /// one never lands after a newer one. Orders writes within one instance
  /// only; `build` waits for this instance's chain before it reads.
  Future<void> _writes = Future.value();

  @override
  Future<DateTime?> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return null;
    await _writes;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_closedKey(userId));
      return stored == null ? null : DateTime.tryParse(stored);
    } catch (e, st) {
      _log.error('Reading the closed review day failed', e, st);
      return null;
    }
  }

  /// Closes the review of [day]: at once, then stored. Does nothing while
  /// signed out.
  Future<void> close(DateTime day) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final closed = startOfDay(day);
    state = AsyncData(closed);
    final key = _closedKey(userId);
    await (_writes = _writes.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, formatIsoDate(closed));
      } catch (e, st) {
        _log.error('Storing the closed review day failed', e, st);
      }
    }));
  }
}

final dailyReviewClosedProvider =
    AsyncNotifierProvider<DailyReviewClosedNotifier, DateTime?>(
      DailyReviewClosedNotifier.new,
    );

/// The review open now ([minuteProvider]), by the profile's review time
/// and the closed day (spec §4.1), or null — also while the profile or the
/// closed day is still loading.
final openReviewDayProvider = Provider<ReviewDay?>((ref) {
  final time = ref.watch(
    profileProvider.select((p) => p.value?.dailyReviewTime),
  );
  if (time == null) return null;
  final closed = ref.watch(dailyReviewClosedProvider);
  if (closed.isLoading) return null;
  return openReviewDay(
    now: ref.watch(minuteProvider),
    reviewMinutes: reviewMinutesOf(time),
    closedDay: closed.value,
  );
});

/// Neither a value nor an error yet.
bool _firstLoad(AsyncValue<Object?> v) => !v.hasValue && !v.hasError;

/// The open review built from that day's entries: [entriesProvider] while
/// it holds that day (today: only then); otherwise, for yesterday,
/// `diaryEntriesProvider(day)`. With the suggestion groups (none if
/// failed), the user's choices (none if failed) and the seams; no pick
/// while either is on its first load ([DailyReview.alternativePending]). Null while not
/// open, signed out, during the Buddy onboarding, while the day's entries
/// are not there, or without a meal that day.
final dailyReviewProvider = Provider<DailyReview?>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return null;
  if (ref.watch(buddyOnboardingRequiredProvider)) return null;
  final day = ref.watch(openReviewDayProvider);
  if (day == null) return null;

  final List<MealEntry> meals;
  final List<GutFeelingEntry> gutFeelings;
  final entries = ref.watch(entriesProvider);
  final entriesDay = entries.day;
  if (entriesDay != null && isSameDay(entriesDay, day.day)) {
    meals = entries.meals;
    gutFeelings = entries.gutFeelings;
  } else if (day.yesterday) {
    final diary = ref.watch(diaryEntriesProvider(day.day)).value;
    if (diary == null) return null;
    meals = [
      for (final e in diary)
        if (e.data case MealDiaryData(:final meal)) meal,
    ];
    gutFeelings = [
      for (final e in diary)
        if (e.data case GutFeelingDiaryData(:final gutFeeling)) gutFeeling,
    ];
  } else {
    return null;
  }

  final suggestions = ref.watch(ingredientSuggestionProvider);
  final choicesLoading = ref.watch(
    alternativeChoicesProvider.select(_firstLoad),
  );
  return buildDailyReview(
    day: day,
    meals: meals,
    gutFeelings: gutFeelings,
    groups: suggestions.value ?? const [],
    chosen: ref.watch(chosenAlternativesProvider),
    alternativeLocked: ref.watch(dailyReviewAlternativeLockedProvider),
    alternativePending: _firstLoad(suggestions) || choicesLoading,
    extras: ref.watch(dailyReviewExtrasProvider),
  );
});

/// Whether the Buddy's review line was said for the review of [day]
/// (`daily_review_said_<userId>`). Unreadable preferences: false (logged).
Future<bool> dailyReviewSaidOn(String userId, DateTime day) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_saidKey(userId)) == formatIsoDate(day);
  } catch (e, st) {
    _log.error('Reading the review line flag failed', e, st);
    return false;
  }
}

/// Records that the Buddy's review line was said for the review of [day].
/// A failed write is logged.
Future<void> recordDailyReviewSaid(String userId, DateTime day) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saidKey(userId), formatIsoDate(day));
  } catch (e, st) {
    _log.error('Storing the review line flag failed', e, st);
  }
}
