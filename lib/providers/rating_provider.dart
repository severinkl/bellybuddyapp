import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../services/app_version_service.dart';
import '../services/rating/rating_rules.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';
import '../utils/settled_value.dart';
import 'auth_provider.dart';
import 'buddy_offers_provider.dart' show onceSuffix;
import 'buddy_onboarding_gate_provider.dart';
import 'buddy_provider.dart';
import 'entries_provider.dart';
import 'insights_provider.dart';
import 'journey_provider.dart';
import 'journey_rewards_provider.dart';
import 'today_provider.dart';
import 'tutorial_provider.dart';

const _log = AppLogger('RatingProvider');

/// The platform's store rating dialog and store page.
abstract class RatingLauncher {
  /// Whether the system can show its rating dialog.
  Future<bool> isAvailable();

  /// Asks the system for its rating dialog (which it may not show).
  Future<void> request();

  /// Opens the app's store page, ready for a review.
  Future<void> openStoreListing();
}

/// [RatingLauncher] over `in_app_review`, the only user of the package.
class _InAppReviewLauncher implements RatingLauncher {
  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> request() => InAppReview.instance.requestReview();

  @override
  Future<void> openStoreListing() => InAppReview.instance.openStoreListing(
    appStoreId: AppConstants.iosAppStoreId,
  );
}

final ratingLauncherProvider = Provider<RatingLauncher>(
  (ref) => _InAppReviewLauncher(),
);

/// Whether the Buddy's first patterns were unlocked and celebrated (rule 1
/// of the rating prompt): on the journey, the day-7 reward was earned and
/// „Muster frei!" was shown (its flag is set); off it, the insights are
/// settled and unlocked; undecided: no.
Future<bool> _patternsCelebrated(Ref ref) async {
  switch (ref.watch(journeyProvider)) {
    case null:
      return false;
    case false:
      return ref.watch(insightsProvider).settledValue?.unlocked ?? false;
    case true:
      if (ref.watch(journeyRewardsProvider)?.patternsFreed != true) {
        return false;
      }
      // Re-checks once the celebration was played (no longer pending).
      ref.watch(
        buddyProvider.select(
          (s) =>
              s.value?.announcements.contains(
                BuddyAnnouncement.patternsUnlocked,
              ) ??
              false,
        ),
      );
      return ref
          .read(buddyProvider.notifier)
          .announcementShown(BuddyAnnouncement.patternsUnlocked, onceSuffix);
  }
}

/// Rules 1, 2, 3, 5 and 6 of the rating prompt (the hero's queue is rule
/// 4): the first patterns are unlocked and celebrated, no onboarding or
/// tutorial runs, today's entries are known (loaded for today, without an
/// error) and have no „Schlecht" Bauchgefühl, this version was not
/// asked yet and the last request is 90 days ago, and the system can show
/// the dialog. False while signed out.
final ratingAskDueProvider = FutureProvider.autoDispose<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  final today = ref.watch(todayProvider);
  if (userId == null) return false;
  if (!await _patternsCelebrated(ref)) return false;
  if (ref.watch(buddyOnboardingRequiredProvider) ||
      ref.watch(tutorialProvider)) {
    return false;
  }
  final (:known, :gutFeelings) = ref.watch(
    entriesProvider.select(
      (s) => (
        known:
            s.day != null &&
            isSameDay(s.day!, today) &&
            !s.isLoading &&
            s.error == null,
        gutFeelings: s.gutFeelings,
      ),
    ),
  );
  // Unknown (not loaded yet, loading, failed): a „Schlecht" entry may hide.
  if (!known || hasHardEntryToday(gutFeelings, today)) return false;

  final (version, prefs) = await (
    ref.watch(appVersionServiceProvider).currentVersion(),
    SharedPreferences.getInstance(),
  ).wait;
  final allowed = ratingAskAllowed(
    currentVersion: version,
    askedVersion: prefs.getString(_askedVersionKey(userId)),
    lastAsk: DateTime.tryParse(prefs.getString(_askedOnKey(userId)) ?? ''),
    today: today,
  );
  if (!allowed) return false;

  try {
    return await ref.watch(ratingLauncherProvider).isAvailable();
  } catch (e, st) {
    _log.error('Checking the rating dialog failed', e, st);
    return false;
  }
});

/// The preference keys of [userId]'s last rating request: its day and its
/// app version.
String _askedOnKey(String userId) =>
    '${AppConstants.keyRatingAskedOnPrefix}$userId';
String _askedVersionKey(String userId) =>
    '${AppConstants.keyRatingAskedVersionPrefix}$userId';

/// Records a rating request of the signed-in user: this app version, today
/// ([ratingAskDueProvider] is false afterwards). Completes once stored; a
/// failure is only logged. Reads [ref] right away: it may run after the
/// caller is gone.
Future<void> recordRatingAsk(WidgetRef ref) async {
  try {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final today = ref.read(todayProvider);
    final versions = ref.read(appVersionServiceProvider);
    final container = ProviderScope.containerOf(ref.context, listen: false);
    final (version, prefs) = await (
      versions.currentVersion(),
      SharedPreferences.getInstance(),
    ).wait;
    // The day first: a failed second write never leaves a version without
    // its day.
    await prefs.setString(_askedOnKey(userId), formatIsoDate(today));
    await prefs.setString(_askedVersionKey(userId), version);
    container.invalidate(ratingAskDueProvider);
  } catch (e, st) {
    _log.error('Recording the rating request failed', e, st);
  }
}
