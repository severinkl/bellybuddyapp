// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/utils/settled_value.dart';

import '../helpers/riverpod_helpers.dart';

void main() {
  test('loaded data: its value', () {
    expect(const AsyncData(3).settledValue, 3);
  });

  test('loading, erroring or refreshing: null, whatever value it holds', () {
    expect(const AsyncLoading<int>().settledValue, isNull);
    expect(
      const AsyncLoading<int>()
          .copyWithPrevious(const AsyncData(3))
          .settledValue,
      isNull,
    );
    expect(
      AsyncError<int>(
        StateError('x'),
        StackTrace.empty,
      ).copyWithPrevious(const AsyncData(3)).settledValue,
      isNull,
    );
  });

  group('in a container', () {
    final user = NotifierProvider<Switchable<String>, String>(
      () => Switchable('a'),
    );
    late Completer<String> load;
    final name = FutureProvider<String>((ref) {
      ref.watch(user);
      return load.future;
    });

    setUp(() => load = Completer());

    Future<ProviderContainer> loaded() async {
      final c = createContainer();
      c.listen(name, (_, _) {});
      load.complete('Ann');
      await c.read(name.future);
      expect(c.read(name).settledValue, 'Ann');
      return c;
    }

    test('a refresh holding the value: null until it is done', () async {
      final c = await loaded();
      load = Completer();

      unawaited(c.refresh(name.future));
      expect(c.read(name).value, 'Ann');
      expect(c.read(name).settledValue, isNull);

      load.complete('Anna');
      await c.read(name.future);
      expect(c.read(name).settledValue, 'Anna');
    });

    test(
      "a dependency's rebuild (another user): null until it is done",
      () async {
        final c = await loaded();
        load = Completer();

        c.read(user.notifier).set('b');
        expect(c.read(name).value, 'Ann');
        expect(c.read(name).settledValue, isNull);

        load.complete('Bob');
        await c.read(name.future);
        expect(c.read(name).settledValue, 'Bob');
      },
    );
  });
}
