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

/// The day-3 first tip after „Ja, gern": one `diet-recommendations` call
/// per user and device, made only once the weekly tips are switched on.
///
/// The request is never retried. Its outcome lands in the journey's
/// rewards ([FirstTipState]); the saved set arrives through the normal
/// tips load. Logs name a status at most, never a meal.
class FirstTipNotifier extends Notifier<void> {
  static const _log = AppLogger('FirstTip');

  /// The [accept] on its way: a second call (a double tap) joins it.
  Future<bool>? _accepting;

  @override
  void build() {}

  /// Switches the weekly tips on, answers the offer „Ja", notes the request
  /// (both stored) and starts it, unawaited. True once started, and when
  /// this device already asked: never a second request.
  ///
  /// False, with nothing changed, when the user, the journey's rewards or
  /// the profile is missing, and when the opt-in write fails: no AI call
  /// with the user's data without it. False too when another user signed
  /// in meanwhile.
  Future<bool> accept() =>
      _accepting ??= _accept().whenComplete(() => _accepting = null);

  Future<bool> _accept() async {
    final userId = ref.read(currentUserIdProvider);
    final rewards = ref.read(journeyRewardsProvider);
    final profile = ref.read(profileProvider).value;
    if (userId == null || rewards == null || profile == null) {
      _log.warn('accept: no user, journey rewards or profile');
      return false;
    }
    if (rewards.firstTip != null) return true;
    try {
      // Fails by throwing (and switches back): never a request then.
      await ref.read(profileProvider.notifier).setWeeklyTips(true);
    } catch (e, st) {
      _log.error('accept: switching the weekly tips on failed', e, st);
      return false;
    }
    if (!_stillFor(userId)) return false;
    await ref
        .read(journeyRewardsProvider.notifier)
        .answerTipOffer(accepted: true);
    if (!_stillFor(userId)) return false;
    await ref
        .read(journeyRewardsProvider.notifier)
        .setFirstTip(FirstTipState.requested);
    if (!_stillFor(userId)) return false;
    unawaited(_request(userId, profile));
    return true;
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
