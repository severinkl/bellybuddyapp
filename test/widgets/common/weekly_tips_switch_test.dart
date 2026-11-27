// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/plus_provider.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/router/route_names.dart';
import 'package:belly_buddy/widgets/common/weekly_tips_switch.dart';

import '../../helpers/app_host.dart';
import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/riverpod_helpers.dart';

/// A repository whose weekly-tips write waits for [release].
class _SlowRepo extends FakeProfileRepository {
  final release = Completer<void>();

  @override
  Future<void> setWeeklyTips(String userId, bool enabled) async {
    await super.setWeeklyTips(userId, enabled);
    await release.future;
  }
}

void main() {
  late FakeProfileRepository repo;

  Future<void> pump(
    WidgetTester tester, {
    FakeProfileRepository? using,
    List<Override> plus = const [],
    bool weeklyTips = false,
  }) async {
    repo = using ?? FakeProfileRepository();
    final profile = testUserProfile().copyWith(weeklyTipsEnabled: weeklyTips);
    repo.seedProfile(profile);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: WeeklyTipsSwitch()),
        ),
        GoRoute(
          path: RoutePaths.plus,
          builder: (_, _) => const Scaffold(body: Text('page:/plus')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(testUserId),
          profileProviderSeededWith(profile),
          ...plus,
        ],
        child: germanRouterApp(router),
      ),
    );
    await tester.pump();
  }

  bool isOn(WidgetTester tester) => tester
      .widget<SwitchListTile>(find.byKey(WeeklyTipsSwitch.switchKey))
      .value;

  testWidgets('shows the title, the Monday subline and the sentence', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Wöchentliche Tipps'), findsOneWidget);
    expect(find.text('Jeden Montag 2–3 Tipps'), findsOneWidget);
    expect(
      find.text(
        'Dafür schicke ich deine Einträge der letzten Wochen, die Muster '
        'daraus und deine Bewertungen meiner Tipps an unseren KI-Dienst.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Mahlzeiten und dein Bauchgefühl der letzten Woche'),
      findsNothing,
    );
    expect(isOn(tester), isFalse);
  });

  testWidgets('flipping it on saves true', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(WeeklyTipsSwitch.switchKey));
    await tester.pumpAndSettle();

    expect(repo.weeklyTipsWrites, [true]);
    expect(isOn(tester), isTrue);
  });

  testWidgets('failure snaps back with a SnackBar, and is logged', (
    tester,
  ) async {
    await pump(tester, using: FakeProfileRepository());
    repo.weeklyTipsError = const PostgrestException(message: 'no column');

    final logs = <String>[];
    final print = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    try {
      await tester.tap(find.byKey(WeeklyTipsSwitch.switchKey));
      await tester.pumpAndSettle();
    } finally {
      debugPrint = print;
    }

    expect(isOn(tester), isFalse);
    expect(find.text(WeeklyTipsSwitch.failure), findsOneWidget);
    expect(
      logs,
      contains('WeeklyTipsSwitch [ERROR]: saving the weekly tips failed'),
    );
  });

  testWidgets('a second tap while saving is ignored', (tester) async {
    final slow = _SlowRepo();
    await pump(tester, using: slow);

    await tester.tap(find.byKey(WeeklyTipsSwitch.switchKey));
    await tester.pump();
    await tester.tap(find.byKey(WeeklyTipsSwitch.switchKey));
    await tester.pump();
    slow.release.complete();
    await tester.pumpAndSettle();

    expect(slow.weeklyTipsWrites, [true]);
  });

  group('Belly Buddy Plus', () {
    final locked = [plusAccessProvider.overrideWithValue(PlusAccess.locked)];
    final open = [plusAccessProvider.overrideWithValue(PlusAccess.open)];
    final switchOff = [paywallEnabledProvider.overrideWithValue(false)];

    for (final stored in [false, true]) {
      testWidgets('locked, stored $stored: the Plus subline, the stored value; '
          'a tap opens /plus and saves nothing', (tester) async {
        await pump(tester, plus: locked, weeklyTips: stored);

        expect(find.text('Wöchentliche Tipps'), findsOneWidget);
        expect(find.text('Mit Belly Buddy Plus'), findsOneWidget);
        expect(find.text('Jeden Montag 2–3 Tipps'), findsNothing);
        expect(find.text(WeeklyTipsSwitch.sentence), findsOneWidget);
        expect(isOn(tester), stored);

        await tester.tap(find.byKey(WeeklyTipsSwitch.switchKey));
        await tester.pumpAndSettle();

        expect(find.text('page:/plus'), findsOneWidget);
        expect(repo.weeklyTipsWrites, isEmpty);
      });
    }

    for (final (name, overrides) in [
      ('open', open),
      ('switch off', switchOff),
    ]) {
      testWidgets('$name: today\'s subline, a tap saves', (tester) async {
        await pump(tester, plus: overrides);

        expect(find.text('Jeden Montag 2–3 Tipps'), findsOneWidget);
        expect(find.text('Mit Belly Buddy Plus'), findsNothing);

        await tester.tap(find.byKey(WeeklyTipsSwitch.switchKey));
        await tester.pumpAndSettle();

        expect(find.text('page:/plus'), findsNothing);
        expect(repo.weeklyTipsWrites, [true]);
        expect(isOn(tester), isTrue);
      });
    }
  });
}
