import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/diary_entry.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/repositories/entry_repository.dart';
import 'package:belly_buddy/screens/diary/widgets/diary_detail_sheets.dart';
import 'package:belly_buddy/utils/diary_helpers.dart';
import 'package:belly_buddy/widgets/common/bb_button.dart';
import 'package:belly_buddy/widgets/common/date_time_chips.dart';

import '../../../../helpers/fixtures.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/riverpod_helpers.dart';

/// One diary entry per kind (gut values within the 1-5 sliders).
DiaryEntry _entryOf(DiaryEntryType type) => DiaryHelpers.buildEntries(
  testEntryQueryResult(gutFeelings: [testGutFeelingEntry(cramps: 1)]),
).firstWhere((e) => e.type == type);

void main() {
  late MockEntryRepository repo;

  setUpAll(() async {
    await initializeDateFormatting('de_DE', null);
  });

  setUp(() {
    repo = MockEntryRepository();
    when(() => repo.deleteByType(any(), any())).thenAnswer((_) async {});
    when(() => repo.updateEntry(any(), any(), any())).thenAnswer((_) async {});
  });

  Future<void> openSheet(WidgetTester tester, DiaryEntry entry) async {
    await tester.pumpWithProviders(
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showDiaryDetailSheet(context, ref, entry),
            child: const Text('öffnen'),
          ),
        ),
      ),
      overrides: [
        entryRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue(testUserId),
      ],
    );
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
  }

  Future<void> tapDelete(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Eintrag löschen'));
    await tester.tap(find.text('Eintrag löschen'));
    await tester.pumpAndSettle();
  }

  group('Eintrag löschen', () {
    for (final type in DiaryEntryType.values) {
      testWidgets('${type.name}: asks first; Abbrechen keeps the entry', (
        tester,
      ) async {
        await openSheet(tester, _entryOf(type));

        await tapDelete(tester);
        expect(find.text('Eintrag löschen?'), findsOneWidget);

        await tester.tap(find.text('Abbrechen'));
        await tester.pumpAndSettle();

        verifyNever(() => repo.deleteByType(any(), any()));
        expect(find.text('Eintrag löschen'), findsOneWidget);
      });
    }

    testWidgets('Löschen deletes, then closes the sheet', (tester) async {
      final entry = _entryOf(DiaryEntryType.toilet);
      final delete = Completer<void>();
      when(
        () => repo.deleteByType(any(), any()),
      ).thenAnswer((_) => delete.future);
      await openSheet(tester, entry);

      await tapDelete(tester);
      await tester.tap(find.text('Löschen'));
      await tester.pump();

      // Still open, busy, while the delete runs.
      verify(() => repo.deleteByType('toilet', entry.id)).called(1);
      expect(find.text('Klo'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      delete.complete();
      await tester.pumpAndSettle();
      expect(find.text('Klo'), findsNothing);
    });

    testWidgets('a failed delete says so and keeps the sheet open', (
      tester,
    ) async {
      when(
        () => repo.deleteByType(any(), any()),
      ).thenThrow(Exception('offline'));
      await openSheet(tester, _entryOf(DiaryEntryType.drink));

      await tapDelete(tester);
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();

      expect(
        find.text('Eintrag konnte nicht gelöscht werden.'),
        findsOneWidget,
      );
      expect(find.text('Eintrag löschen'), findsOneWidget);
    });
  });

  group('Bearbeiten', () {
    Future<void> startEditing(WidgetTester tester, DiaryEntryType type) async {
      await openSheet(tester, _entryOf(type));
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
    }

    for (final type in [
      DiaryEntryType.toilet,
      DiaryEntryType.drink,
      DiaryEntryType.gutFeeling,
    ]) {
      testWidgets('${type.name}: date and time can be changed', (tester) async {
        await startEditing(tester, type);
        final moved = DateTime(2026, 3, 22, 8, 15);

        tester
            .widget<DateTimeChips>(find.byType(DateTimeChips))
            .onChanged(moved);
        await tester.pump();
        expect(find.text('22.03.2026'), findsOneWidget);
        expect(find.text('08:15'), findsOneWidget);

        await tester.ensureVisible(find.text('Speichern'));
        await tester.tap(find.text('Speichern'));
        await tester.pumpAndSettle();

        final data =
            verify(
                  () =>
                      repo.updateEntry(any(), _entryOf(type).id, captureAny()),
                ).captured.single
                as Map<String, dynamic>;
        expect(DateTime.parse(data['tracked_at'] as String), moved);
        expect(find.text('Speichern'), findsNothing);
      });
    }

    testWidgets('the date chips show only while editing', (tester) async {
      await openSheet(tester, _entryOf(DiaryEntryType.toilet));
      expect(find.byType(DateTimeChips), findsNothing);

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      expect(find.byType(DateTimeChips), findsOneWidget);
    });

    testWidgets('Speichern is the standard primary button', (tester) async {
      await startEditing(tester, DiaryEntryType.toilet);

      final button = find.ancestor(
        of: find.text('Speichern'),
        matching: find.byType(BbButton),
      );
      expect(button, findsOneWidget);
    });

    testWidgets('a failed save says so and keeps editing', (tester) async {
      when(
        () => repo.updateEntry(any(), any(), any()),
      ).thenThrow(Exception('offline'));
      await startEditing(tester, DiaryEntryType.toilet);

      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      expect(find.text('Fehler beim Speichern.'), findsOneWidget);
      expect(find.text('Speichern'), findsOneWidget);
    });

    testWidgets('a drink keeps its note when edited', (tester) async {
      final drink = testDrinkEntry().copyWith(notes: 'mit Zitrone');
      final entry = DiaryEntry(
        id: drink.id,
        type: DiaryEntryType.drink,
        trackedAt: drink.trackedAt,
        title: drink.drinkName,
        subtitle: '',
        data: DrinkDiaryData(drink),
      );
      await openSheet(tester, entry);
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      final data =
          verify(
                () => repo.updateEntry(any(), drink.id, captureAny()),
              ).captured.single
              as Map<String, dynamic>;
      expect(data['notes'], 'mit Zitrone');
    });

    testWidgets('a drink amount over 3000 ml cannot be saved', (tester) async {
      await startEditing(tester, DiaryEntryType.drink);

      await tester.enterText(find.byType(TextField), '99999');
      await tester.pump();

      expect(find.text('Bitte gib 1 bis 3000 ml ein.'), findsOneWidget);
      final save = tester.widget<BbButton>(
        find.ancestor(
          of: find.text('Speichern'),
          matching: find.byType(BbButton),
        ),
      );
      expect(save.onPressed, isNull);

      await tester.enterText(find.byType(TextField), '750');
      await tester.pump();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      final data =
          verify(
                () => repo.updateEntry(any(), any(), captureAny()),
              ).captured.single
              as Map<String, dynamic>;
      expect(data['amount_ml'], 750);
    });
  });
}
