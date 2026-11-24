import 'package:belly_buddy/config/constants.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/router/app_router.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/screens/diary/widgets/diary_entry_card.dart';
import 'package:belly_buddy/widgets/buddy/streak_chip.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:belly_buddy/widgets/log_sheet/log_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_host.dart';
import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';

/// Monday, 23 Nov 2026, 12:40.
final _now = DateTime(2026, 11, 23, 12, 40);

/// The shell on a 402×874 phone with a home indicator; today has one Klo
/// entry in [entries].
Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  FakeEntryRepository? entries,
}) async {
  tester.view
    ..physicalSize = const Size(402, 874)
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: 62, bottom: 34);
  addTearDown(tester.view.reset);
  final container = ProviderContainer.test(
    overrides: [
      ...baseOverrides(
        entries: (entries ?? FakeEntryRepository())
          ..seedResult(
            testEntryQueryResult(
              meals: [],
              toiletEntries: [
                testToiletEntry(trackedAt: DateTime(2026, 11, 23, 9)),
              ],
              gutFeelings: [],
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
  return container;
}

String _path(ProviderContainer container) =>
    container.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

/// The top of the bottom bar: its wave and the plus that rises above it.
double _barTop(WidgetTester tester) => [
  tester.getRect(find.byType(BbBottomNav)).top,
  tester.getRect(find.byKey(BbBottomNav.centerButtonKey)).top,
].reduce((a, b) => a < b ? a : b);

void main() {
  setUpAll(() => initializeDateFormatting('de_DE'));

  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyNotificationModalShown: true,
    });
  });

  testWidgets('„Dein Streak" dims the whole screen, the bar included: a tap '
      'on a tab closes it and stays on Home', (tester) async {
    final container = await _pumpShell(tester);

    await tester.tap(find.byType(StreakChip));
    await tester.pumpAndSettle();
    expect(find.text('Dein Streak'), findsOneWidget);

    // Its scrim lies over the bar.
    final scrim = tester.getRect(find.byType(ModalBarrier).last);
    expect(
      scrim.contains(tester.getCenter(find.byKey(BbBottomNav.navDiaryKey))),
      isTrue,
    );

    await tester.tap(
      find.byKey(BbBottomNav.navDiaryKey),
      warnIfMissed: false, // the scrim takes it
    );
    await tester.pumpAndSettle();
    expect(find.text('Dein Streak'), findsNothing);
    expect(_path(container), RoutePaths.dashboard);

    // Nothing left behind on Home either.
    await tester.tap(find.byKey(BbBottomNav.navDiaryKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BbBottomNav.navHomeKey));
    await tester.pumpAndSettle();
    expect(find.text('Dein Streak'), findsNothing);
  });

  testWidgets('a Tagebuch detail sheet opens above the bar and the plus: '
      '„Eintrag löschen" can be reached, the plus cannot', (tester) async {
    final container = await _pumpShell(tester);
    await tester.tap(find.byKey(BbBottomNav.navDiaryKey));
    await tester.pumpAndSettle();
    expect(_path(container), RoutePaths.diary);

    await tester.tap(find.byType(DiaryEntryCard));
    await tester.pumpAndSettle();
    final delete = find.text('Eintrag löschen');
    expect(delete, findsOneWidget);

    // Pulled all the way up, the end of the sheet clears the home
    // indicator.
    await tester.drag(find.text('Klo').last, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.getRect(delete).bottom, lessThanOrEqualTo(874 - 34));

    // Its scrim lies over the bar and the plus: a tap there opens no
    // „Eintragen" sheet.
    final scrim = tester.getRect(find.byType(ModalBarrier).last);
    expect(scrim.top, lessThanOrEqualTo(0 + 62));
    expect(scrim.bottom, greaterThanOrEqualTo(_barTop(tester)));
    await tester.tapAt(tester.getCenter(find.byKey(BbBottomNav.navHomeKey)));
    await tester.pumpAndSettle();
    expect(find.byType(LogSheet), findsNothing);
    expect(_path(container), RoutePaths.diary);
  });

  group('a Tagebuch detail sheet shows its own errors above the scrim', () {
    Future<void> openKloSheet(
      WidgetTester tester,
      FakeEntryRepository entries,
    ) async {
      await _pumpShell(tester, entries: entries);
      await tester.tap(find.byKey(BbBottomNav.navDiaryKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DiaryEntryCard));
      await tester.pumpAndSettle();
    }

    testWidgets('a failed delete', (tester) async {
      await openKloSheet(tester, FakeEntryRepository(throwOnDelete: true));

      await tester.ensureVisible(find.text('Eintrag löschen'));
      await tester.tap(find.text('Eintrag löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Löschen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Readable and in front: not on the shell's Scaffold under the sheet.
      expect(
        find.text('Eintrag konnte nicht gelöscht werden.').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Eintrag löschen'), findsOneWidget);
    });

    testWidgets('a failed save', (tester) async {
      await openKloSheet(tester, FakeEntryRepository(throwOnUpdate: true));

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Speichern'));
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Fehler beim Speichern.').hitTestable(), findsOneWidget);
      expect(find.text('Speichern'), findsOneWidget);
    });
  });
}
