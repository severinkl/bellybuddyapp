import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/entries_provider.dart';
import 'package:belly_buddy/screens/dashboard/widgets/tutorial/tutorial_keys.dart';
import 'package:belly_buddy/services/buddy/daily_care.dart';
import 'package:belly_buddy/utils/date_format_utils.dart';
import 'package:belly_buddy/widgets/common/bb_bottom_nav.dart';
import 'package:belly_buddy/widgets/log_sheet/log_sheet.dart';

import '../../helpers/app_host.dart';

/// Monday, 23 Nov 2026, 12:40: nothing logged yet, so lunch is next.
final _now = DateTime(2026, 11, 23, 12, 40);

/// A real GoRouter with the four tab branches and [BbBottomNav] as the bar.
GoRouter _buildRouter() {
  StatefulShellBranch branch(String path, String label) => StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) => Center(child: Text('$label Screen')),
      ),
    ],
  );
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => Scaffold(
          body: shell,
          bottomNavigationBar: BbBottomNav(navigationShell: shell),
        ),
        branches: [
          branch('/home', 'Home'),
          branch('/diary', 'Diary'),
          branch('/discover', 'Discover'),
          branch('/me', 'Me'),
        ],
      ),
    ],
  );
}

/// Home's entries ([entriesProvider]) as loaded for [day], with nothing
/// logged.
class _HomeLoaded extends EntriesNotifier {
  _HomeLoaded(this.day);

  final DateTime day;

  @override
  EntriesState build() => EntriesState(day: day);
}

/// The bar, with Home's entries loaded for [homeDay] (today by default).
Future<void> _pumpNav(WidgetTester tester, {DateTime? homeDay}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        buddyClockProvider.overrideWithValue(() => _now),
        entriesProvider.overrideWith(
          () => _HomeLoaded(homeDay ?? startOfDay(_now)),
        ),
      ],
      child: germanRouterApp(_buildRouter()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

/// Only [need] is highlighted in the sheet (none for null).
void _expectSelected(WidgetTester tester, CareNeed? need) {
  for (final option in CareNeed.values) {
    expect(
      tester.getSemantics(find.byKey(LogSheet.optionKey(option))),
      isSemantics(isSelected: option == need, hasSelectedState: true),
      reason: option.name,
    );
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('de_DE'));

  group('BbBottomNav', () {
    testWidgets('renders the four tab labels and „Eintragen" in the middle', (
      tester,
    ) async {
      await _pumpNav(tester);
      for (final label in [
        'Home',
        'Tagebuch',
        'Eintragen',
        'Entdecken',
        'Ich',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Essen tracken'), findsNothing);
    });

    testWidgets('the active tab shows its filled icon', (tester) async {
      await _pumpNav(tester);
      // Home active, the others outlined.
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);

      await _tap(tester, BbBottomNav.navDiscoverKey);
      expect(find.text('Discover Screen'), findsOneWidget);
      expect(find.byIcon(Icons.explore), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);

      await _tap(tester, BbBottomNav.navMeKey);
      expect(find.text('Me Screen'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
    });

    testWidgets('the active tab is selected to assistive tech, the others are '
        'not; „Eintragen" is a button', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpNav(tester);

      void expectTabs(Key active) {
        for (final (key, label) in [
          (BbBottomNav.navHomeKey, 'Home'),
          (BbBottomNav.navDiaryKey, 'Tagebuch'),
          (BbBottomNav.navDiscoverKey, 'Entdecken'),
          (BbBottomNav.navMeKey, 'Ich'),
        ]) {
          expect(
            tester.getSemantics(find.byKey(key)),
            isSemantics(
              label: label,
              isButton: true,
              hasSelectedState: true,
              isSelected: key == active,
              hasTapAction: true,
            ),
            reason: label,
          );
        }
      }

      expectTabs(BbBottomNav.navHomeKey);
      await _tap(tester, BbBottomNav.navDiscoverKey);
      expectTabs(BbBottomNav.navDiscoverKey);

      expect(
        tester.getSemantics(find.byKey(BbBottomNav.centerButtonKey)),
        isSemantics(label: 'Eintragen', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('the tour targets the plus, Tagebuch, Entdecken and Ich', (
      tester,
    ) async {
      await _pumpNav(tester);
      for (final (key, label) in [
        (TutorialKeys.tagebuch, 'Tagebuch'),
        (TutorialKeys.entdecken, 'Entdecken'),
        (TutorialKeys.ich, 'Ich'),
      ]) {
        expect(
          find.descendant(of: find.byKey(key), matching: find.text(label)),
          findsOneWidget,
          reason: label,
        );
      }
      // The plus circle itself, inside the centre button.
      expect(
        find.descendant(
          of: find.byKey(BbBottomNav.centerButtonKey),
          matching: find.byKey(TutorialKeys.plus),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(TutorialKeys.plus),
          matching: find.byIcon(Icons.add),
        ),
        findsOneWidget,
      );
    });

    testWidgets('plus on Entdecken logs for now with the suggestion', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpNav(tester);
      await _tap(tester, BbBottomNav.navDiscoverKey);

      await _tap(tester, BbBottomNav.centerButtonKey);
      expect(find.text('Heute · 12:40'), findsOneWidget);
      _expectSelected(tester, CareNeed.food);
      handle.dispose();
    });

    testWidgets('plus on the Tagebuch showing today logs for now with the '
        'suggestion', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpNav(tester);
      // Tapping the tab shows today.
      await _tap(tester, BbBottomNav.navDiaryKey);

      await _tap(tester, BbBottomNav.centerButtonKey);
      expect(find.text('Heute · 12:40'), findsOneWidget);
      _expectSelected(tester, CareNeed.food);
      handle.dispose();
    });

    testWidgets('after midnight, with Home still on yesterday, the plus '
        'suggests nothing', (tester) async {
      final handle = tester.ensureSemantics();
      // Home loaded yesterday; the clock is past midnight on Entdecken.
      await _pumpNav(tester, homeDay: DateTime(2026, 11, 22));
      await _tap(tester, BbBottomNav.navDiscoverKey);

      await _tap(tester, BbBottomNav.centerButtonKey);
      expect(find.text('Heute · 12:40'), findsOneWidget);
      _expectSelected(tester, null);
      handle.dispose();
    });

    for (final (phone, size, padding) in [
      ('375×667', const Size(375, 667), FakeViewPadding.zero),
      // A home-indicator phone: the bar loses its extra bottom space.
      ('402×874', const Size(402, 874), const FakeViewPadding(bottom: 34)),
    ]) {
      for (final scale in [1.6, 2.0, 3.0]) {
        testWidgets('fits a $phone phone at accessibility text scale $scale: '
            'no overflow, every label whole', (tester) async {
          tester.view
            ..physicalSize = size
            ..devicePixelRatio = 1
            ..padding = padding;
          addTearDown(tester.view.reset);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _pumpNav(tester);
          expect(tester.takeException(), isNull);

          // Each tab once, so each label is drawn active (bold) too.
          for (final key in [
            BbBottomNav.navDiaryKey,
            BbBottomNav.navDiscoverKey,
            BbBottomNav.navMeKey,
            BbBottomNav.navHomeKey,
          ]) {
            await _tap(tester, key);
            expect(tester.takeException(), isNull, reason: '$key');
          }
          final bar = tester.getRect(find.byType(BbBottomNav));
          for (final label in ['Home', 'Tagebuch', 'Eintragen', 'Entdecken']) {
            final rect = tester.getRect(find.text(label));
            expect(rect.bottom, lessThanOrEqualTo(bar.bottom), reason: label);
            expect(rect.top, greaterThanOrEqualTo(bar.top), reason: label);
          }
        });
      }
    }

    testWidgets('before Home loaded anything, the plus suggests nothing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [buddyClockProvider.overrideWithValue(() => _now)],
          child: germanRouterApp(_buildRouter()),
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, BbBottomNav.centerButtonKey);
      _expectSelected(tester, null);
      handle.dispose();
    });
  });
}
