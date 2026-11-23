import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/screens/trackers/gut_feeling/gut_feeling_tracker_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_host.dart';
import '../helpers/fakes.dart';

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
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      semantics.dispose();
    }, variant: platforms);
  });
}
