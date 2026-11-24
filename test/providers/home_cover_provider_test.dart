import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test(
    'a page covers Home until it closes, past the sheet that opened it',
    () async {
      final c = container();
      final cover = c.read(homeCoveredProvider.notifier);
      final page = Completer<void>();

      await cover.whileOpen(() async => cover.leftHome(page.future));
      expect(c.read(homeCoveredProvider), isTrue);

      page.complete();
      await pumpEventQueue();
      expect(c.read(homeCoveredProvider), isFalse);
    },
  );

  test('another tab (no page) covers nothing', () {
    final c = container();
    c.read(homeCoveredProvider.notifier).leftHome(null);
    expect(c.read(homeCoveredProvider), isFalse);
  });

  test('Home hidden: a page no longer covers it, a sheet still does', () async {
    final c = container();
    final cover = c.read(homeCoveredProvider.notifier);
    final sheet = Completer<void>();

    // A page that never closes (removed by a `go`, not popped).
    cover.leftHome(Completer<void>().future);
    unawaited(cover.whileOpen(() => sheet.future));
    cover.homeHidden();
    expect(c.read(homeCoveredProvider), isTrue);

    sheet.complete();
    await pumpEventQueue();
    expect(c.read(homeCoveredProvider), isFalse);
  });

  test('another user: uncovered', () async {
    final c = container();
    c.read(homeCoveredProvider.notifier).leftHome(Completer<void>().future);
    expect(c.read(homeCoveredProvider), isTrue);

    user.set(c, 'u2');

    expect(c.read(homeCoveredProvider), isFalse);
  });
}
