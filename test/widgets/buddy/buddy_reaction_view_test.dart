// ignore_for_file: invalid_use_of_internal_member
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/buddy_repository.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/services/buddy/buddy_copy.dart';
import 'package:belly_buddy/services/buddy/buddy_mood_logic.dart';
import 'package:belly_buddy/widgets/buddy/buddy.dart';
import 'package:belly_buddy/widgets/buddy/buddy_reaction_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/ambient_animations.dart';
import '../../helpers/fakes.dart';
import '../../helpers/riverpod_helpers.dart';

late FakeBuddyRepository _buddyRepo;

List<Override> _overrides() => [
  buddyRepositoryProvider.overrideWithValue(_buddyRepo),
  entryRepositoryProvider.overrideWithValue(FakeEntryRepository()),
  currentUserIdProvider.overrideWithValue('u1'),
];

Future<void> _pumpView(WidgetTester tester, Widget view) =>
    tester.pumpWithProviders(
      Scaffold(body: Center(child: view)),
      overrides: _overrides(),
    );

BuddyController _controllerOf(WidgetTester tester) =>
    tester.widget<AnimatedBuddy>(find.byType(AnimatedBuddy)).controller;

/// Lets the real (engine) image decode finish, pumping until the reaction
/// has started; fails after ~500 ms of real time.
Future<void> _awaitReaction(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    if (_controllerOf(tester).currentAction != null) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  fail('The reaction did not start: the photo decode never completed.');
}

/// A tiny PNG rendered by the engine.
Future<Uint8List> _png(WidgetTester tester) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(
      recorder,
    ).drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..color = Colors.white);
    final image = await recorder.endRecording().toImage(4, 4);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

void main() {
  // These Buddies must tick: reactions, blinks, waking up.
  tickBuddiesInTests();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _buddyRepo = FakeBuddyRepository();
  });

  group('BuddyReactionView', () {
    testWidgets('meal plays eat and says a meal line', (tester) async {
      await _pumpView(
        tester,
        const BuddyReactionView(
          kind: EntryKind.meal,
          sentiment: LogSentiment.good,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      final c = _controllerOf(tester);
      expect(c.currentAction, BuddyAction.eat);
      expect(BuddyCopy.meal, contains(c.bubble));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(c.bubble!), findsOneWidget);
    });

    testWidgets('toilet + bad hugs and turns empathetic', (tester) async {
      await _pumpView(
        tester,
        const BuddyReactionView(
          kind: EntryKind.toilet,
          sentiment: LogSentiment.bad,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      final c = _controllerOf(tester);
      expect(c.currentAction, BuddyAction.hug);
      expect(c.mood, BuddyMood.empathetic);
      expect(BuddyCopy.toiletBad, contains(c.bubble));
    });

    const cases = <(EntryKind, LogSentiment, BuddyAction)>[
      (EntryKind.drink, LogSentiment.good, BuddyAction.drink),
      (EntryKind.toilet, LogSentiment.good, BuddyAction.relief),
      (EntryKind.gutFeeling, LogSentiment.good, BuddyAction.celebrate),
      (EntryKind.gutFeeling, LogSentiment.neutral, BuddyAction.nodYes),
      (EntryKind.gutFeeling, LogSentiment.bad, BuddyAction.hug),
    ];
    for (final (kind, sentiment, action) in cases) {
      testWidgets('${kind.name} + ${sentiment.name} plays ${action.name}', (
        tester,
      ) async {
        await _pumpView(
          tester,
          BuddyReactionView(kind: kind, sentiment: sentiment),
        );
        await tester.pump(const Duration(milliseconds: 16));

        final c = _controllerOf(tester);
        expect(c.currentAction, action);
        expect(c.bubble, isNotEmpty);
      });
    }

    testWidgets('is a stage of the given height', (tester) async {
      await _pumpView(
        tester,
        const BuddyReactionView(
          kind: EntryKind.drink,
          sentiment: LogSentiment.good,
        ),
      );

      expect(find.byType(BuddyStage), findsOneWidget);
      expect(
        tester.getSize(find.byType(BuddyStage)).height,
        AppConstants.buddyReactionSize,
      );
    });

    testWidgets('shrinks to the height it is given', (tester) async {
      await _pumpView(
        tester,
        const SizedBox(
          height: 150,
          child: BuddyReactionView(
            kind: EntryKind.drink,
            sentiment: LogSentiment.good,
          ),
        ),
      );

      expect(tester.getSize(find.byType(BuddyStage)).height, 150);
    });

    testWidgets('names the Buddy after buddyProvider', (tester) async {
      _buddyRepo.store['u1'] = const BuddyState(name: 'Bauchi');
      await _pumpView(
        tester,
        const BuddyReactionView(
          kind: EntryKind.drink,
          sentiment: LogSentiment.good,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        tester.widget<AnimatedBuddy>(find.byType(AnimatedBuddy)).name,
        'Bauchi',
      );
    });

    testWidgets('falls back to "Buddy" when buddyProvider fails', (
      tester,
    ) async {
      _buddyRepo.throwOnFetch = true;
      await _pumpView(
        tester,
        const BuddyReactionView(
          kind: EntryKind.drink,
          sentiment: LogSentiment.good,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        tester.widget<AnimatedBuddy>(find.byType(AnimatedBuddy)).name,
        'Buddy',
      );
      expect(_controllerOf(tester).currentAction, BuddyAction.drink);
    });

    testWidgets('eats the decoded meal photo and disposes it afterwards', (
      tester,
    ) async {
      final bytes = await _png(tester);
      await _pumpView(
        tester,
        BuddyReactionView(
          kind: EntryKind.meal,
          sentiment: LogSentiment.good,
          foodImageBytes: bytes,
        ),
      );
      await _awaitReaction(tester);
      await tester.pump(const Duration(milliseconds: 16));

      final c = _controllerOf(tester);
      expect(c.currentAction, BuddyAction.eat);
      final food = c.frame.food;
      expect(food, isNotNull);
      expect(food!.debugDisposed, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(food.debugDisposed, isTrue);
    });

    testWidgets('undecodable photo bytes fall back to the apple', (
      tester,
    ) async {
      await _pumpView(
        tester,
        BuddyReactionView(
          kind: EntryKind.meal,
          sentiment: LogSentiment.good,
          foodImageBytes: Uint8List.fromList(const [1, 2, 3, 4]),
        ),
      );
      await _awaitReaction(tester);
      await tester.pump(const Duration(milliseconds: 16));

      final c = _controllerOf(tester);
      expect(c.currentAction, BuddyAction.eat);
      expect(c.frame.food, isNull);
      expect(BuddyCopy.meal, contains(c.bubble));
    });

    testWidgets('unmounting before the photo is decoded plays nothing', (
      tester,
    ) async {
      final bytes = await _png(tester);
      await _pumpView(
        tester,
        BuddyReactionView(
          kind: EntryKind.meal,
          sentiment: LogSentiment.good,
          foodImageBytes: bytes,
        ),
      );
      final c = _controllerOf(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }

      expect(c.currentAction, isNull);
    });
  });
}
