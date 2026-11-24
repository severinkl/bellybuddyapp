import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:belly_buddy/providers/home_cover_provider.dart';

import '../helpers/riverpod_helpers.dart';

void main() {
  final user = SwitchableUserId();

  ProviderContainer container() =>
      ProviderContainer.test(overrides: [user.override]);

  test('uncovered at first', () {
    expect(container().read(homeCoveredProvider), isFalse);
  });

  test('a sheet covers Home until it is done', () async {
    final c = container();
    final sheet = Completer<int>();

    final result = c
        .read(homeCoveredProvider.notifier)
        .whileOpen(() => sheet.future);
    expect(c.read(homeCoveredProvider), isTrue);

    sheet.complete(3);
    expect(await result, 3);
    expect(c.read(homeCoveredProvider), isFalse);
  });

  test('covered from before the sheet opens', () async {
    final c = container();
    bool? coveredWhenOpening;

    await c.read(homeCoveredProvider.notifier).whileOpen(() async {
      coveredWhenOpening = c.read(homeCoveredProvider);
    });

    expect(coveredWhenOpening, isTrue);
    expect(c.read(homeCoveredProvider), isFalse);
  });

  test('a failing sheet uncovers Home too', () async {
    final c = container();

    await expectLater(
      c
          .read(homeCoveredProvider.notifier)
          .whileOpen<void>(() => Future.error(StateError('gone'))),
      throwsStateError,
    );
    expect(c.read(homeCoveredProvider), isFalse);
  });

  test("Home's route not on top (a page, another tab) covers it until it is "
      'again', () {
    final c = container();
    final cover = c.read(homeCoveredProvider.notifier);

    cover.homeCurrent(false);
    expect(c.read(homeCoveredProvider), isTrue);
    cover.homeCurrent(false);
    expect(c.read(homeCoveredProvider), isTrue);

    cover.homeCurrent(true);
    expect(c.read(homeCoveredProvider), isFalse);
  });

  test('something over the app covers Home until it ends, past the sheet '
      'that opened it', () async {
    final c = container();
    final cover = c.read(homeCoveredProvider.notifier);
    final back = Completer<void>();

    await cover.whileOpen(() async => cover.leftHome(back.future));
    expect(c.read(homeCoveredProvider), isTrue);

    back.complete();
    await pumpEventQueue();
    expect(c.read(homeCoveredProvider), isFalse);
  });

  test('every cover counts: Home is free once none is left', () async {
    final c = container();
    final cover = c.read(homeCoveredProvider.notifier);
    final sheet = Completer<void>();
    final popup = _route();

    unawaited(cover.whileOpen(() => sheet.future));
    cover
      ..popupOpened(popup)
      ..homeCurrent(false);

    sheet.complete();
    await pumpEventQueue();
    expect(c.read(homeCoveredProvider), isTrue);
    cover.popupClosed(popup);
    expect(c.read(homeCoveredProvider), isTrue);
    cover.homeCurrent(true);
    expect(c.read(homeCoveredProvider), isFalse);
  });

  test('another user: uncovered', () async {
    final c = container();
    c.read(homeCoveredProvider.notifier)
      ..popupOpened(_route())
      ..homeCurrent(false);
    expect(c.read(homeCoveredProvider), isTrue);

    user.set(c, 'u2');

    expect(c.read(homeCoveredProvider), isFalse);
  });

  group('HomeCoverObserver', () {
    final watched = GlobalKey<NavigatorState>();
    final other = GlobalKey<NavigatorState>();

    /// Home on [watched], next to a tab's navigator [other], both observed.
    Future<ProviderContainer> pumpNavigators(WidgetTester tester) async {
      final c = container();
      addTearDown(c.dispose);
      HomeCoverObserver observer() => HomeCoverObserver(
        () => c.read(homeCoveredProvider.notifier),
        navigators: [watched],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            navigatorKey: watched,
            navigatorObservers: [observer()],
            home: Scaffold(
              body: Row(
                children: [
                  const Expanded(child: Text('Home')),
                  Expanded(
                    child: Navigator(
                      key: other,
                      observers: [observer()],
                      onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (_) => const Text('another tab'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return c;
    }

    testWidgets('a sheet or dialog over Home covers it until it is closed', (
      tester,
    ) async {
      final c = await pumpNavigators(tester);
      final context = watched.currentContext!;

      unawaited(
        showModalBottomSheet<void>(
          context: context,
          builder: (_) => const Text('sheet'),
        ),
      );
      await tester.pumpAndSettle();
      expect(c.read(homeCoveredProvider), isTrue);
      unawaited(
        showDialog<void>(context: context, builder: (_) => const Text('dlg')),
      );
      await tester.pumpAndSettle();

      watched.currentState!.pop();
      await tester.pumpAndSettle();
      expect(c.read(homeCoveredProvider), isTrue);
      watched.currentState!.pop();
      await tester.pumpAndSettle();
      expect(c.read(homeCoveredProvider), isFalse);
    });

    testWidgets('covered as soon as the sheet is pushed, before a frame', (
      tester,
    ) async {
      final c = await pumpNavigators(tester);

      unawaited(
        showModalBottomSheet<void>(
          context: watched.currentContext!,
          builder: (_) => const Text('sheet'),
        ),
      );

      expect(c.read(homeCoveredProvider), isTrue);
    });

    testWidgets('a removed sheet no longer covers Home', (tester) async {
      final c = await pumpNavigators(tester);
      final sheet = ModalBottomSheetRoute<void>(
        builder: (_) => const Text('sheet'),
        isScrollControlled: false,
      );
      unawaited(watched.currentState!.push(sheet));
      await tester.pumpAndSettle();
      expect(c.read(homeCoveredProvider), isTrue);

      watched.currentState!.removeRoute(sheet);
      await tester.pumpAndSettle();
      expect(c.read(homeCoveredProvider), isFalse);
    });

    testWidgets("pages are the router's, another tab's sheets not Home's", (
      tester,
    ) async {
      final c = await pumpNavigators(tester);

      unawaited(
        watched.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Text('page')),
        ),
      );
      await tester.pumpAndSettle();
      expect(c.read(homeCoveredProvider), isFalse);
      watched.currentState!.pop();
      await tester.pumpAndSettle();

      unawaited(
        showModalBottomSheet<void>(
          context: other.currentContext!,
          useRootNavigator: false,
          builder: (_) => const Text('a tab sheet'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('a tab sheet'), findsOneWidget);
      expect(c.read(homeCoveredProvider), isFalse);
    });
  });
}

/// A sheet's route, never pushed.
Route<void> _route() => ModalBottomSheetRoute<void>(
  builder: (_) => const SizedBox(),
  isScrollControlled: false,
);
