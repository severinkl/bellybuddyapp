import 'package:belly_buddy/models/app_config.dart';
import 'package:belly_buddy/providers/app_config_provider.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/relief_provider.dart';
import 'package:belly_buddy/services/relief/relief_content.dart';
import 'package:belly_buddy/services/relief/relief_rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/logs.dart';

const _warning = 'akuthilfe_enabled is on but content is unreviewed';

ProviderContainer _gate({
  required bool preview,
  bool? switchOn,
  List<ReliefExercise>? content,
}) {
  final container = ProviderContainer(
    overrides: [
      reliefPreviewProvider.overrideWithValue(preview),
      appConfigProvider.overrideWith(
        (ref) => switchOn == null
            ? Future<AppConfig>.error(StateError('offline'))
            : AppConfig(
                minimum: '1.0.0',
                latest: '1.0.0',
                akuthilfeEnabled: switchOn,
              ),
      ),
      if (content != null) reliefContentProvider.overrideWithValue(content),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<bool> _enabled(ProviderContainer c) async {
  try {
    await c.read(appConfigProvider.future);
  } catch (_) {}
  return c.read(reliefEnabledProvider);
}

ProviderContainer _feedback(String? userId) {
  final container = ProviderContainer(
    overrides: [currentUserIdProvider.overrideWithValue(userId)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetReliefWarningForTest();
  });

  group('reliefEnabledProvider', () {
    test('switch on but content unreviewed stays off, warns once', () async {
      final logs = captureLogs();
      final c = _gate(preview: false, switchOn: true);
      expect(await _enabled(c), isFalse);
      c.invalidate(reliefEnabledProvider);
      expect(c.read(reliefEnabledProvider), isFalse);
      expect(logs.where((l) => l.contains(_warning)), hasLength(1));
    });

    test('switch off is off', () async {
      expect(await _enabled(_gate(preview: false, switchOn: false)), isFalse);
    });

    test('config fetch error is off', () async {
      expect(await _enabled(_gate(preview: false)), isFalse);
    });

    test('preview wins over a switch that is off', () async {
      expect(await _enabled(_gate(preview: true, switchOn: false)), isTrue);
    });

    test('switch on with all content reviewed is on', () async {
      final reviewed = [
        for (final e in reliefExercises)
          ReliefExercise(
            id: e.id,
            title: e.title,
            subtitle: e.subtitle,
            steps: e.steps,
            caution: e.caution,
            reviewed: true,
          ),
      ];
      final c = _gate(preview: false, switchOn: true, content: reviewed);
      expect(await _enabled(c), isTrue);
    });

    test('review markers follow the preview flag', () {
      expect(_gate(preview: true).read(reliefReviewMarkersProvider), isTrue);
      expect(_gate(preview: false).read(reliefReviewMarkersProvider), isFalse);
    });
  });

  group('reliefFeedbackProvider', () {
    test('record stores the map under the user key', () async {
      final c = _feedback('test-user');
      await c.read(reliefFeedbackProvider.future);
      await c
          .read(reliefFeedbackProvider.notifier)
          .record('waerme', ReliefAnswer.yes);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('relief_feedback_test-user'), '{"waerme":"yes"}');
      expect(c.read(reliefFeedbackProvider).value, {
        'waerme': ReliefAnswer.yes,
      });
    });

    test('two users keep separate maps', () async {
      for (final (user, answer) in [
        ('a', ReliefAnswer.yes),
        ('b', ReliefAnswer.no),
      ]) {
        final c = _feedback(user);
        await c.read(reliefFeedbackProvider.future);
        await c.read(reliefFeedbackProvider.notifier).record('waerme', answer);
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('relief_feedback_a'), '{"waerme":"yes"}');
      expect(prefs.getString('relief_feedback_b'), '{"waerme":"no"}');
    });

    test('corrupt stored value is empty and logged once', () async {
      SharedPreferences.setMockInitialValues({
        'relief_feedback_u': 'not json {"gedanken":"yes"}',
      });
      final logs = captureLogs();
      final c = _feedback('u');
      expect(await c.read(reliefFeedbackProvider.future), isEmpty);
      c.invalidate(reliefFeedbackProvider);
      expect(await c.read(reliefFeedbackProvider.future), isEmpty);
      final lines = logs.where((l) => l.contains('corrupt')).toList();
      expect(lines, hasLength(1));
      expect(lines.single, isNot(contains('gedanken')));
    });

    test('a non-string stored value is empty and logged once', () async {
      SharedPreferences.setMockInitialValues({'relief_feedback_u': 42});
      final logs = captureLogs();
      final c = _feedback('u');
      expect(await c.read(reliefFeedbackProvider.future), isEmpty);
      expect(logs.where((l) => l.contains('corrupt')), hasLength(1));
    });

    test('no user stores nothing', () async {
      final c = _feedback(null);
      await c.read(reliefFeedbackProvider.future);
      await c
          .read(reliefFeedbackProvider.notifier)
          .record('waerme', ReliefAnswer.yes);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });

    test('ordered exercises follow the stored answers', () async {
      SharedPreferences.setMockInitialValues({
        'relief_feedback_u': '{"gedanken":"yes"}',
      });
      final c = _feedback('u');
      await c.read(reliefFeedbackProvider.future);
      expect(c.read(orderedReliefExercisesProvider).first.id, 'gedanken');
    });

    test('content order while loading', () {
      final c = _feedback('u');
      expect(
        c.read(orderedReliefExercisesProvider).map((e) => e.id),
        reliefExercises.map((e) => e.id),
      );
    });
  });
}
