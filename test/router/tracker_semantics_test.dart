import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/screens/diary/widgets/detail_sheets/detail_sheet_scaffold.dart';
import 'package:belly_buddy/screens/diary/widgets/diary_entry_card.dart';
import 'package:belly_buddy/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_host.dart';
import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';

/// Monday, 23 Nov 2026, 12:40.
final _now = DateTime(2026, 11, 23, 12, 40);

/// Every attached semantics node, in paint order.
List<SemanticsNode> _nodes(WidgetTester tester) {
  final root = tester
      .binding
      .renderViews
      .first
      .owner!
      .semanticsOwner!
      .rootSemanticsNode!;
  final nodes = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    nodes.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return nodes;
}

/// The nodes placed in the traversal order of a parent elsewhere (an
/// [OverlayPortal]'s overlay child, e.g. a Slider's value indicator) whose
/// parent is not in the tree. iOS drops such a child; when its parent turns
/// up later and lists it, the engine makes up a node with the root's id and
/// empties the root: VoiceOver and UI tests then see nothing, on every
/// screen, until the app restarts.
List<int> _orphans(WidgetTester tester) {
  final nodes = _nodes(tester);
  final parents = {
    for (final n in nodes) ?n.getSemanticsData().traversalParentIdentifier,
  };
  return [
    for (final n in nodes)
      if (n.getSemanticsData().traversalChildIdentifier case final id?)
        if (!parents.contains(id)) n.id,
  ];
}

Future<void> _pumpHome(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(500, 874)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer.test(
    overrides: [
      ...baseOverrides(entries: FakeEntryRepository()),
      buddyTodayProvider.overrideWithValue(() => _now),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const AppTestHost()),
  );
  await tester.pumpAndSettle();
}

/// The Tagebuch on a 402×874 phone; today has one Bauchgefühl entry.
Future<void> _pumpDiary(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(402, 874)
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: 62, bottom: 34);
  addTearDown(tester.view.reset);
  final container = ProviderContainer.test(
    overrides: [
      ...baseOverrides(
        entries: FakeEntryRepository()
          ..seedResult(
            testEntryQueryResult(
              meals: [],
              toiletEntries: [],
              gutFeelings: [
                testGutFeelingEntry(
                  cramps: 3,
                  trackedAt: DateTime(2026, 11, 23, 10),
                ),
              ],
              drinks: [],
            ),
          ),
      ),
      buddyTodayProvider.overrideWithValue(() => _now),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const AppTestHost()),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(BbBottomNav.navDiaryKey));
  await tester.pumpAndSettle();
}

/// Pumps [frames] frames, checking for orphans in each.
Future<void> _expectNoOrphans(
  WidgetTester tester,
  String step, {
  int frames = 40,
}) async {
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    expect(_orphans(tester), isEmpty, reason: '$step, frame $frame');
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyNotificationModalShown: true,
    });
  });

  const platforms = TargetPlatformVariant({
    TargetPlatform.iOS,
    TargetPlatform.android,
  });

  group('Bauchgefühl tracker semantics', () {
    testWidgets('no overlay child is ever in the tree without its parent, '
        'from opening to leaving', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpHome(tester);

      await tester.tap(find.bySemanticsLabel('Bauchgefühl eintragen'));
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(_orphans(tester), isEmpty, reason: 'opening, frame $frame');
      }
      expect(find.byType(GutFeelingTrackerScreen), findsOneWidget);

      // To the Stimmung page and back: its sliders come and go.
      await tester.tap(find.text('Stimmung'));
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(_orphans(tester), isEmpty, reason: 'paging, frame $frame');
      }

      await tester.tap(find.byIcon(Icons.arrow_back));
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(_orphans(tester), isEmpty, reason: 'leaving, frame $frame');
      }
      semantics.dispose();
    }, variant: platforms);

    testWidgets('Home\'s semantics tree is complete after visiting and '
        'leaving the tracker', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpHome(tester);
      final before = _nodes(tester).length;
      expect(before, greaterThan(10));

      await tester.tap(find.bySemanticsLabel('Bauchgefühl eintragen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(GutFeelingTrackerScreen), findsNothing);
      expect(_nodes(tester).length, before);
      for (final label in [
        'Essen eintragen',
        'Trinken eintragen',
        'Bauchgefühl eintragen',
        'Klo eintragen',
        'Home',
        'Tagebuch',
        'Ich',
      ]) {
        // „Home" is the screen's heading and the bar's tab.
        expect(
          find.bySemanticsLabel(label),
          findsNWidgets(label == 'Home' ? 2 : 1),
          reason: label,
        );
      }
      semantics.dispose();
    }, variant: platforms);
  });

  group('Tagebuch Bauchgefühl edit sheet semantics', () {
    testWidgets('its sliders leave no overlay child without its parent, '
        'from opening to closing, and the Tagebuch is complete after', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpDiary(tester);
      final before = _nodes(tester).length;
      final sheet = find.byType(DetailSheetScaffold);

      Future<void> openAndEditStimmung() async {
        await tester.tap(find.byType(DiaryEntryCard));
        await _expectNoOrphans(tester, 'opening');

        await tester.tap(find.byIcon(Icons.edit));
        await _expectNoOrphans(tester, 'editing');
        expect(find.byType(Slider), findsNWidgets(4));

        await tester.tap(find.text('Stimmung').last);
        await _expectNoOrphans(tester, 'Stimmung');
        expect(find.byType(Slider), findsNWidgets(5));
      }

      await openAndEditStimmung();
      // Down near the sheet's smallest size: the lower sliders leave the
      // viewport; then all the way up and through the content.
      await tester.drag(sheet, const Offset(0, 200));
      await _expectNoOrphans(tester, 'shrinking');
      expect(sheet, findsOneWidget);
      await tester.drag(sheet, const Offset(0, -800));
      await _expectNoOrphans(tester, 'growing');
      await tester.drag(sheet, const Offset(0, -400));
      await _expectNoOrphans(tester, 'scrolling');

      // Closed by its scrim.
      await tester.tapAt(const Offset(200, 70));
      await _expectNoOrphans(tester, 'closing by the scrim', frames: 60);
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);

      // Closed by dragging it down: the sliders slide out of view.
      await openAndEditStimmung();
      await tester.drag(sheet, const Offset(0, 500));
      await _expectNoOrphans(tester, 'closing by a drag', frames: 60);
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);

      expect(_nodes(tester).length, before);
      for (final label in ['Home', 'Tagebuch', 'Ich']) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      semantics.dispose();
    }, variant: platforms);
  });
}
