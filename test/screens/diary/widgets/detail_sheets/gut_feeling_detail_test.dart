import 'dart:ui' show SemanticsFlag;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/models/diary_entry.dart';
import 'package:belly_buddy/models/gut_feeling_entry.dart';
import 'package:belly_buddy/screens/diary/widgets/detail_sheets/gut_feeling_detail.dart';
import 'package:belly_buddy/screens/diary/widgets/detail_sheets/gut_feeling_edit_state.dart';
import 'package:belly_buddy/screens/diary/widgets/diary_entry_card.dart';
import 'package:belly_buddy/widgets/common/mascot_image.dart';

import '../../../../helpers/riverpod_helpers.dart';

GutFeelingEntry _gut({
  int bloating = 1,
  int gas = 1,
  int cramps = 1,
  int fullness = 1,
  int? stress,
}) => GutFeelingEntry(
  id: 'gut-1',
  trackedAt: DateTime(2026, 11, 22, 12),
  bloating: bloating,
  gas: gas,
  cramps: cramps,
  fullness: fullness,
  stress: stress,
);

GutFeelingEditState _editState(GutFeelingEntry gut) =>
    GutFeelingEditState.fromEntry(
      gut,
      onBloatingChanged: (_) {},
      onGasChanged: (_) {},
      onCrampsChanged: (_) {},
      onFullnessChanged: (_) {},
      onStressChanged: (_) {},
      onHappinessChanged: (_) {},
      onEnergyChanged: (_) {},
      onFocusChanged: (_) {},
      onBodyFeelChanged: (_) {},
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE', null);
  });

  Future<void> pumpDetail(
    WidgetTester tester,
    GutFeelingEntry gut, {
    GutFeelingEditState? editState,
  }) => tester.pumpWithProviders(
    Scaffold(
      body: SingleChildScrollView(
        child: GutFeelingDetail(
          gut: gut,
          isEditing: editState != null,
          editState: editState,
        ),
      ),
    ),
  );

  group('GutFeelingDetail', () {
    testWidgets('editing: VoiceOver reads each slider by its name and as '
        '„N von 5"', (tester) async {
      final semantics = tester.ensureSemantics();
      final gut = _gut(bloating: 3);
      await pumpDetail(tester, gut, editState: _editState(gut));
      await tester.pumpAndSettle();

      final node = find.semantics
          .byFlag(SemanticsFlag.isSlider)
          .evaluate()
          .first;
      expect(node.label, AppConstants.gutFeelingSymptoms[0]);
      expect(node.value, '3 von 5');
      expect(node.value, isNot(contains('%')));
      semantics.dispose();
    });

    testWidgets('shows the level and the strongest symptom, no average', (
      tester,
    ) async {
      await pumpDetail(tester, _gut(bloating: 3));

      expect(find.text('Durchschnittlich'), findsOneWidget);
      expect(find.text('Stärkstes Symptom: 3 von 5'), findsOneWidget);
      expect(find.textContaining('5.0'), findsNothing);
      expect(find.textContaining('5,0'), findsNothing);
    });

    testWidgets('Krämpfe 5 and Völlegefühl 5 read as Schlecht', (tester) async {
      await pumpDetail(tester, _gut(cramps: 5, fullness: 5));

      expect(find.text('Schlecht'), findsOneWidget);
      expect(find.text('Stärkstes Symptom: 5 von 5'), findsOneWidget);
    });

    testWidgets('no symptom reads as Sehr gut, without complaints', (
      tester,
    ) async {
      await pumpDetail(tester, _gut(stress: 5));

      expect(find.text('Sehr gut'), findsOneWidget);
      expect(find.text('Keine Beschwerden'), findsOneWidget);
    });

    testWidgets('while editing, the rating follows the edited values', (
      tester,
    ) async {
      final stored = _gut();
      await pumpDetail(
        tester,
        stored,
        editState: _editState(stored.copyWith(gas: 4)),
      );

      expect(find.text('Schlecht'), findsOneWidget);
      expect(find.text('Stärkstes Symptom: 4 von 5'), findsOneWidget);
    });

    testWidgets('while editing, an unset mood reads „nicht angegeben"', (
      tester,
    ) async {
      final stored = _gut(stress: 2);
      await pumpDetail(tester, stored, editState: _editState(stored));

      await tester.tap(find.text('Stimmung'));
      await tester.pump();

      expect(find.text('2 / 5'), findsOneWidget);
      expect(find.text('nicht angegeben'), findsNWidgets(4));
    });

    testWidgets('the edit rows fit the sheet of a 402 pt phone', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(354, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final stored = _gut(cramps: 3);
      await pumpDetail(tester, stored, editState: _editState(stored));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Stimmung'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('nicht angegeben'), findsNWidgets(5));
    });
  });

  group('DiaryEntryCard', () {
    testWidgets('a hard day shows the sad Buddy', (tester) async {
      final gut = _gut(cramps: 5, fullness: 5);
      await tester.pumpWithProviders(
        Scaffold(
          body: DiaryEntryCard(
            entry: DiaryEntry(
              id: gut.id,
              type: DiaryEntryType.gutFeeling,
              trackedAt: gut.trackedAt,
              title: 'Bauchgefühl',
              subtitle: '',
              data: GutFeelingDiaryData(gut),
            ),
            onTap: () {},
          ),
        ),
      );

      final mascot = tester.widget<MascotImage>(find.byType(MascotImage));
      expect(mascot.assetPath, AppConstants.mascotSad);
    });
  });
}
