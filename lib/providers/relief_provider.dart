import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../services/relief/relief_content.dart';
import '../services/relief/relief_rules.dart';
import '../utils/logger.dart';
import 'app_config_provider.dart';
import 'auth_provider.dart';

const _log = AppLogger('Relief');

bool _warned = false;
bool _corruptLogged = false;

/// Lets a test see the once-per-process warning again.
@visibleForTesting
void resetReliefWarningForTest() {
  _warned = false;
  _corruptLogged = false;
}

/// The exercises; tests override it.
final reliefContentProvider = Provider<List<ReliefExercise>>(
  (_) => reliefExercises,
);

/// Debug builds and `--dart-define=RELIEF_PREVIEW=true` see the feature
/// regardless of the remote switch and the review state.
final reliefPreviewProvider = Provider<bool>(
  (_) => kDebugMode || const bool.fromEnvironment('RELIEF_PREVIEW'),
);

/// Whether "Ruhe für den Bauch" is visible: preview, or the remote switch
/// is on and every exercise is reviewed.
final reliefEnabledProvider = Provider<bool>((ref) {
  if (ref.watch(reliefPreviewProvider)) return true;
  final switchOn = ref.watch(appConfigProvider).value?.akuthilfeEnabled == true;
  if (!switchOn) return false;
  if (ref.watch(reliefContentProvider).every((e) => e.reviewed)) return true;
  if (!_warned) {
    _warned = true;
    _log.warn('akuthilfe_enabled is on but content is unreviewed; staying off');
  }
  return false;
});

/// Whether unreviewed exercises are marked as drafts.
final reliefReviewMarkersProvider = Provider<bool>(
  (ref) => ref.watch(reliefPreviewProvider),
);

/// The user's answers per exercise, kept on this device only under
/// `relief_feedback_<userId>`.
class ReliefFeedbackNotifier extends AsyncNotifier<Map<String, ReliefAnswer>> {
  @override
  Future<Map<String, ReliefAnswer>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return {};
    final prefs = await SharedPreferences.getInstance();
    Map<String, ReliefAnswer>? parsed;
    try {
      parsed = tryParseReliefAnswers(
        prefs.getString('${AppConstants.keyReliefFeedbackPrefix}$userId'),
      );
    } catch (_) {
      // Not a string under the key (TypeError): corrupt like bad JSON.
      parsed = null;
    }
    if (parsed != null) return parsed;
    if (!_corruptLogged) {
      _corruptLogged = true;
      _log.warn('Stored feedback is corrupt; treating it as empty');
    }
    return {};
  }

  /// Stores [answer] for [exerciseId]; does nothing while signed out.
  Future<void> record(String exerciseId, ReliefAnswer answer) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final current = await future;
    if (!ref.mounted) return;
    final next = {...current, exerciseId: answer};
    state = AsyncData(next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${AppConstants.keyReliefFeedbackPrefix}$userId',
        jsonEncode({for (final e in next.entries) e.key: e.value.name}),
      );
    } catch (e) {
      _log.error('Could not store the answer', e);
    }
  }
}

final reliefFeedbackProvider =
    AsyncNotifierProvider<ReliefFeedbackNotifier, Map<String, ReliefAnswer>>(
      ReliefFeedbackNotifier.new,
    );

/// The exercises, liked ones first; content order while loading or failed.
final orderedReliefExercisesProvider = Provider<List<ReliefExercise>>((ref) {
  final all = ref.watch(reliefContentProvider);
  final answers = ref.watch(reliefFeedbackProvider).value;
  return answers == null ? all : orderedExercises(all, answers);
});
