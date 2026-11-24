import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../models/first_tip.dart';
import '../models/journey_rewards.dart';
import '../models/user_profile.dart';
import '../repositories/recommendation_repository.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';
import 'journey_rewards_provider.dart';
import 'profile_provider.dart';
import 'recommendation_provider.dart';

/// What [FirstTipNotifier.accept] did.
enum FirstTipAcceptance {
  /// The weekly tips are on and the first tip is on its way, or this
  /// device already asked for it.
  started,

  /// Switching the weekly tips on failed, or another user signed in
  /// meanwhile: nothing requested.
  failed,

  /// Nothing to do it with yet: no user, no journey rewards, or no profile
  /// (none, failed, or still loading after
  /// [AppConstants.firstTipProfileWait]; another user signed in while it
  /// waited). Nothing changed or requested: the offer is not answered.
  notReady,
}

/// The day-3 first tip after „Ja, gern": one `diet-recommendations` call
/// per user and device, made only once the weekly tips are switched on.
///
/// The request is never retried. Its outcome lands in the journey's
/// rewards ([FirstTipState]); the saved set arrives through the normal
/// tips load. Logs name a status at most, never a meal.
class FirstTipNotifier extends Notifier<void> {
  static const _log = AppLogger('FirstTip');

  /// The [accept] on its way: a second call (a double tap) joins it.
  Future<FirstTipAcceptance>? _accepting;

  @override
  void build() {}

  /// Switches the weekly tips on, answers the offer „Ja", notes the request
  /// (both stored) and starts it, unawaited: [FirstTipAcceptance.started],
  /// also when this device already asked (never a second request).
  ///
  /// A profile still (re)loading is waited for, at most
  /// [AppConstants.firstTipProfileWait]. [FirstTipAcceptance.notReady],
  /// with nothing changed, when the user, the journey's rewards or the
  /// profile is missing (then too). [FirstTipAcceptance.failed] when the
  /// opt-in write fails (no AI call with the user's data without it) or
  /// another user signed in meanwhile.
  Future<FirstTipAcceptance> accept() =>
      _accepting ??= _accept().whenComplete(() => _accepting = null);

  Future<FirstTipAcceptance> _accept() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || ref.read(journeyRewardsProvider) == null) {
      _log.warn('accept: no user or journey rewards');
      return FirstTipAcceptance.notReady;
    }
    final profile = await _settledProfile();
    if (!_stillFor(userId)) return FirstTipAcceptance.notReady;
    final rewards = ref.read(journeyRewardsProvider);
    if (rewards == null || profile == null) {
      _log.warn('accept: no journey rewards or profile');
      return FirstTipAcceptance.notReady;
    }
    if (rewards.firstTip != null) return FirstTipAcceptance.started;
    try {
      // Fails by throwing (and switches back): never a request then.
      await ref.read(profileProvider.notifier).setWeeklyTips(true);
    } catch (e, st) {
      _log.error('accept: switching the weekly tips on failed', e, st);
      return FirstTipAcceptance.failed;
    }
    if (!_stillFor(userId)) return FirstTipAcceptance.failed;
    await ref
        .read(journeyRewardsProvider.notifier)
        .answerTipOffer(accepted: true);
    if (!_stillFor(userId)) return FirstTipAcceptance.failed;
    await ref
        .read(journeyRewardsProvider.notifier)
        .setFirstTip(FirstTipState.requested);
    if (!_stillFor(userId)) return FirstTipAcceptance.failed;
    unawaited(_request(userId, profile));
    return FirstTipAcceptance.started;
  }

  /// The profile once it is no longer loading, waiting at most
  /// [AppConstants.firstTipProfileWait]; null without one (none, failed,
  /// still loading).
  Future<UserProfile?> _settledProfile() async {
    final now = ref.read(profileProvider);
    if (!now.isLoading) return now.value;
    final settled = Completer<UserProfile?>();
    final sub = ref.listen(profileProvider, (_, next) {
      if (!next.isLoading && !settled.isCompleted) settled.complete(next.value);
    });
    try {
      return await settled.future.timeout(
        AppConstants.firstTipProfileWait,
        onTimeout: () => null,
      );
    } finally {
      sub.close();
    }
  }

  /// The one request, with the profile's intolerances and diet (core reads
  /// the last days' meals itself), at most [AppConstants.firstTipTimeout].
  /// Done with a saved set holding tips, and the sets reload; failed
  /// otherwise (a saved set without tips is never „new":
  /// `unseenTipSetProvider` skips it). Dropped once another user is signed
  /// in.
  Future<void> _request(String userId, UserProfile profile) async {
    try {
      final result = await ref
          .read(recommendationRepositoryProvider)
          .requestFirstTip(
            intolerances: profile.intolerances,
            diet: profile.diet,
          )
          .timeout(AppConstants.firstTipTimeout);
      if (!_stillFor(userId)) return;
      if (result.ok) {
        await _set(FirstTipState.done);
        if (!_stillFor(userId)) return;
        unawaited(
          ref.read(recommendationProvider.notifier).fetchRecommendations(),
        );
        return;
      }
      _log.warn(
        'First tip failed: ${result.tips} tips, '
        '${result.id == null ? 'not saved' : 'saved'}',
      );
      await _set(FirstTipState.failed);
    } on FirstTipException catch (e) {
      _log.error('First tip failed (${e.status ?? 'no status'})');
      await _failFor(userId);
    } on TimeoutException {
      _log.error('First tip failed: no answer in time');
      await _failFor(userId);
    } catch (e) {
      _log.error('First tip failed (${e.runtimeType})');
      await _failFor(userId);
    }
  }

  Future<void> _set(FirstTipState firstTip) =>
      ref.read(journeyRewardsProvider.notifier).setFirstTip(firstTip);

  /// Notes the failure, unless another user signed in meanwhile.
  Future<void> _failFor(String userId) async {
    if (_stillFor(userId)) await _set(FirstTipState.failed);
  }

  /// Whether [userId] is still signed in; logged when not, and the rest
  /// dropped.
  bool _stillFor(String userId) {
    if (ref.isCurrentUser(userId)) return true;
    _log.warn('First tip: another user signed in meanwhile, dropped');
    return false;
  }
}

final firstTipProvider = NotifierProvider<FirstTipNotifier, void>(
  FirstTipNotifier.new,
);
