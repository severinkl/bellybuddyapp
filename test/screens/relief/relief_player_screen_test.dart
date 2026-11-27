import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/providers/relief_player_provider.dart';
import 'package:belly_buddy/providers/relief_provider.dart';
import 'package:belly_buddy/screens/relief/relief_player_screen.dart';
import 'package:belly_buddy/screens/relief/widgets/relief_safety.dart';
import 'package:belly_buddy/services/relief/relief_content.dart';
import 'package:belly_buddy/services/relief/relief_rules.dart';
import 'package:belly_buddy/services/relief/screen_awake.dart';

import '../../helpers/app_lifecycle.dart';
import '../../helpers/layout_checks.dart';

class _FakeScreenAwake implements ScreenAwake {
  final calls = <bool>[];

  @override
  Future<void> set(bool on) async => calls.add(on);
}

final _recorded = <(String, ReliefAnswer)>[];

class _FakeFeedback extends ReliefFeedbackNotifier {
  @override
  Future<Map<String, ReliefAnswer>> build() async => {};

  @override
  Future<void> record(String exerciseId, ReliefAnswer answer) async =>
      _recorded.add((exerciseId, answer));
}

void main() {
  late _FakeScreenAwake awake;

  setUp(() {
    awake = _FakeScreenAwake();
    _recorded.clear();
  });

  ReliefExercise exercise(String id) => reliefExerciseById(id)!;

  /// Pumps a home page with the player for [id] pushed on top of it.
  Future<void> pumpPlayer(
    WidgetTester tester,
    String id, {
    bool markers = false,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reliefClockProvider.overrideWithValue(
            () => tester.binding.clock.now(),
          ),
          screenAwakeProvider.overrideWithValue(awake),
          reliefFeedbackProvider.overrideWith(_FakeFeedback.new),
          reliefReviewMarkersProvider.overrideWithValue(markers),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReliefPlayerScreen(exerciseId: id),
                  ),
                ),
                child: const Text('home'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndPump(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
  }

  Future<void> seconds(WidgetTester tester, int n) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> finish(WidgetTester tester, String id) async {
    await tapAndPump(tester, ReliefCopy.start);
    for (var i = 0; i < exercise(id).steps.length; i++) {
      await tapAndPump(tester, ReliefCopy.next);
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('views', () {
    testWidgets('ready shows the caution, „Starten" and the safety line', (
      tester,
    ) async {
      await pumpPlayer(tester, 'bauchmassage');
      expect(find.text(exercise('bauchmassage').caution!), findsOneWidget);
      expect(find.text(ReliefCopy.start), findsOneWidget);
      expect(find.byType(ReliefSafetyLine), findsOneWidget);
    });

    testWidgets('running counts steps, pauses and resumes', (tester) async {
      await pumpPlayer(tester, 'bauchmassage');
      await tapAndPump(tester, ReliefCopy.start);
      expect(find.text(ReliefCopy.stepOf(1, 6)), findsOneWidget);
      expect(find.text(exercise('bauchmassage').steps[0].text), findsOneWidget);
      expect(find.text('0:20'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(ReliefSafetyLine), findsNothing);
      expect(find.byTooltip(ReliefCopy.safetySheetTitle), findsOneWidget);

      await tapAndPump(tester, ReliefCopy.pause);
      expect(find.text(ReliefCopy.resume), findsOneWidget);
      await tapAndPump(tester, ReliefCopy.resume);
      expect(find.text(ReliefCopy.pause), findsOneWidget);
    });

    testWidgets('„Weiter" on the last step finishes', (tester) async {
      await pumpPlayer(tester, 'bauchmassage');
      await finish(tester, 'bauchmassage');
      expect(find.text(ReliefCopy.doneLine), findsOneWidget);
      expect(find.text(ReliefCopy.helpedQuestion), findsOneWidget);
      expect(find.byType(ReliefSafetyLine), findsOneWidget);
    });

    testWidgets('close leaves at once', (tester) async {
      await pumpPlayer(tester, 'bauchatmung');
      await tapAndPump(tester, ReliefCopy.start);
      await tester.tap(find.byTooltip(ReliefCopy.close));
      await tester.pumpAndSettle();
      expect(find.byType(ReliefPlayerScreen), findsNothing);
      expect(_recorded, isEmpty);
    });
  });

  group('leaving the app', () {
    testWidgets('pauses a running step', (tester) async {
      await pumpPlayer(tester, 'bauchatmung');
      await tapAndPump(tester, ReliefCopy.start);
      returnFromBackground();
      await tester.pump();
      expect(find.text(ReliefCopy.resume), findsOneWidget);
      expect(awake.calls.last, isFalse);
    });

    testWidgets('keeps the quiet warmth step counting', (tester) async {
      await pumpPlayer(tester, 'waerme');
      await tapAndPump(tester, ReliefCopy.start);
      for (var i = 0; i < 3; i++) {
        await tapAndPump(tester, ReliefCopy.next);
      }
      returnFromBackground();
      await tester.pump();
      expect(find.text(ReliefCopy.pause), findsOneWidget);
    });
  });

  group('screen awake', () {
    testWidgets('on while running, off on pause', (tester) async {
      await pumpPlayer(tester, 'bauchatmung');
      expect(awake.calls, isEmpty);
      await tapAndPump(tester, ReliefCopy.start);
      expect(awake.calls, [true]);
      await tapAndPump(tester, ReliefCopy.pause);
      expect(awake.calls.last, isFalse);
    });

    testWidgets('off during the quiet warmth step', (tester) async {
      await pumpPlayer(tester, 'waerme');
      await tapAndPump(tester, ReliefCopy.start);
      for (var i = 0; i < 3; i++) {
        await tapAndPump(tester, ReliefCopy.next);
      }
      expect(exercise('waerme').steps[3].quiet, isTrue);
      expect(awake.calls.last, isFalse);
    });

    testWidgets('off when leaving the screen', (tester) async {
      await pumpPlayer(tester, 'bauchatmung');
      await tapAndPump(tester, ReliefCopy.start);
      expect(awake.calls.last, isTrue);
      await tester.tap(find.byTooltip(ReliefCopy.close));
      await tester.pumpAndSettle();
      expect(awake.calls.last, isFalse);
    });

    testWidgets('off when done', (tester) async {
      await pumpPlayer(tester, 'bauchatmung');
      await finish(tester, 'bauchatmung');
      expect(awake.calls.last, isFalse);
    });
  });

  group('announcements', () {
    testWidgets('a step change announces the new step text once', (
      tester,
    ) async {
      await pumpPlayer(tester, 'bauchatmung');
      await tapAndPump(tester, ReliefCopy.start);
      tester.takeAnnouncements();
      await seconds(tester, 20);
      final messages = tester.takeAnnouncements().map((a) => a.message);
      expect(
        messages.where((m) => m == exercise('bauchatmung').steps[1].text),
        hasLength(1),
      );
    });

    testWidgets('breathing announces phase words only, never digits', (
      tester,
    ) async {
      await pumpPlayer(tester, 'bauchatmung');
      await tapAndPump(tester, ReliefCopy.start);
      await tapAndPump(tester, ReliefCopy.next);
      await tapAndPump(tester, ReliefCopy.next);
      tester.takeAnnouncements();
      await seconds(tester, 10);
      final messages = tester
          .takeAnnouncements()
          .map((a) => a.message)
          .toList();
      expect(messages, isNotEmpty);
      for (final m in messages) {
        expect(['Einatmen', 'Ausatmen', 'Halten'], contains(m));
        expect(m, isNot(matches(RegExp(r'\d'))));
      }
    });
  });

  group('done', () {
    testWidgets('„Nein" is stored and offers the safety sheet', (tester) async {
      await pumpPlayer(tester, 'bauchatmung');
      await finish(tester, 'bauchatmung');
      await tester.ensureVisible(find.text(ReliefCopy.answerNo));
      await tapAndPump(tester, ReliefCopy.answerNo);
      expect(_recorded, [('bauchatmung', ReliefAnswer.no)]);
      expect(find.text(ReliefCopy.thanksNo), findsOneWidget);
      expect(find.text(ReliefCopy.answerNo), findsNothing);
      expect(find.text(ReliefCopy.safetyLinkLabel), findsOneWidget);
    });

    testWidgets('„Ja" thanks', (tester) async {
      await pumpPlayer(tester, 'gedanken');
      await finish(tester, 'gedanken');
      await tester.ensureVisible(find.text(ReliefCopy.answerYes));
      await tapAndPump(tester, ReliefCopy.answerYes);
      expect(_recorded, [('gedanken', ReliefAnswer.yes)]);
      expect(find.text(ReliefCopy.thanks), findsOneWidget);
    });

    testWidgets('„Fertig" without an answer stores nothing and leaves', (
      tester,
    ) async {
      await pumpPlayer(tester, 'bauchatmung');
      await finish(tester, 'bauchatmung');
      await tester.ensureVisible(find.text(ReliefCopy.done));
      await tester.tap(find.text(ReliefCopy.done));
      await tester.pumpAndSettle();
      expect(_recorded, isEmpty);
      expect(find.byType(ReliefPlayerScreen), findsNothing);
    });
  });

  group('review marker', () {
    testWidgets('shown for an unreviewed exercise in preview', (tester) async {
      await pumpPlayer(tester, 'bauchatmung', markers: true);
      expect(find.text(ReliefCopy.draftMarker), findsOneWidget);
    });

    testWidgets('absent without preview', (tester) async {
      await pumpPlayer(tester, 'bauchatmung');
      expect(find.text(ReliefCopy.draftMarker), findsNothing);
    });
  });

  testWidgets('at 200 % text on a small phone the controls stay usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final errors = await collectFlutterErrors(() async {
      await pumpPlayer(tester, 'bauchmassage', textScale: 2);
      await tapAndPump(tester, ReliefCopy.start);
      for (var i = 0; i < 3; i++) {
        await tapAndPump(tester, ReliefCopy.next);
      }
    });

    expect(find.text(ReliefCopy.stepOf(4, 6)), findsOneWidget);
    expect(verticalOverflows(errors), isEmpty);
    expect(find.text(ReliefCopy.next).hitTestable(), findsOneWidget);
  });
}
