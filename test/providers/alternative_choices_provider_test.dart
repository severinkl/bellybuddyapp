import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/alternative_choice.dart';
import 'package:belly_buddy/models/replacement_ingredient.dart';
import 'package:belly_buddy/providers/alternative_choices_provider.dart';
import 'package:belly_buddy/services/alternative_choice_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/riverpod_helpers.dart';

Map<String, dynamic> row(
  String id, {
  String ing = 'i1',
  String rep = 'r1',
  String choice = 'try',
  String at = '2026-11-27T10:00:00+00:00',
}) => {
  'id': id,
  'ingredient_id': ing,
  'replacement_ingredient_id': rep,
  'choice': choice,
  'created_at': at,
  'ingredient': {'name': 'Zwiebel'},
  'replacement': {'name': 'Lauch'},
};

class FakeService implements AlternativeChoiceService {
  Future<List<Map<String, dynamic>>> Function(String userId) onFetch =
      (_) async => [];
  Future<Map<String, dynamic>> Function() onUpsert = () async => row('srv');
  Future<void> Function(String id) onDelete = (_) async {};
  int fetches = 0;
  final deleted = <String>[];

  @override
  Future<List<Map<String, dynamic>>> fetch(String userId) {
    fetches++;
    return onFetch(userId);
  }

  @override
  Future<Map<String, dynamic>> upsert({
    required String userId,
    required String ingredientId,
    required String replacementId,
    required AlternativeChoiceKind kind,
  }) => onUpsert();

  @override
  Future<void> delete(String id) {
    deleted.add(id);
    return onDelete(id);
  }
}

void main() {
  late FakeService service;
  late SwitchableUserId user;

  ProviderContainer make({String? userId = testUserId}) {
    user = SwitchableUserId(userId);
    return createContainer(
      overrides: [
        alternativeChoiceServiceProvider.overrideWithValue(service),
        user.override,
      ],
    );
  }

  const rep = ReplacementIngredient(id: 'r1', name: 'Lauch');

  setUp(() => service = FakeService());

  test('signed out: empty list, no fetch', () async {
    final c = make(userId: null);
    expect(await c.read(alternativeChoicesProvider.future), isEmpty);
    expect(service.fetches, 0);
  });

  test('choose tryIt: in state at once; server row replaces it', () async {
    final c = make();
    await c.read(alternativeChoicesProvider.future);
    final held = Completer<Map<String, dynamic>>();
    service.onUpsert = () => held.future;

    final result = c
        .read(alternativeChoicesProvider.notifier)
        .choose(
          ingredientId: 'i1',
          ingredientName: 'Zwiebel',
          replacement: rep,
          kind: AlternativeChoiceKind.tryIt,
        );
    final during = c.read(alternativeChoicesProvider).value!;
    expect(during, hasLength(1));
    expect(during.single.replacementName, 'Lauch');
    expect(c.read(chosenAlternativesProvider), {('i1', 'r1')});

    held.complete(row('srv'));
    expect(await result, isTrue);
    final after = c.read(alternativeChoicesProvider).value!;
    expect(after.map((e) => e.id), ['srv']);
    expect(c.read(chosenAlternativesProvider), {('i1', 'r1')});
  });

  test('choose replaces an existing row for the same pair', () async {
    service.onFetch = (_) async => [row('old', choice: 'skip')];
    final c = make();
    await c.read(alternativeChoicesProvider.future);
    service.onUpsert = () async => row('old');

    await c
        .read(alternativeChoicesProvider.notifier)
        .choose(
          ingredientId: 'i1',
          ingredientName: 'Zwiebel',
          replacement: rep,
          kind: AlternativeChoiceKind.tryIt,
        );
    final list = c.read(alternativeChoicesProvider).value!;
    expect(list, hasLength(1));
    expect(list.single.kind, AlternativeChoiceKind.tryIt);
  });

  test('choose fails: state as before, returns false', () async {
    service.onFetch = (_) async => [row('old', ing: 'i9', rep: 'r9')];
    final c = make();
    await c.read(alternativeChoicesProvider.future);
    service.onUpsert = () async => throw Exception('boom');

    final ok = await c
        .read(alternativeChoicesProvider.notifier)
        .choose(
          ingredientId: 'i1',
          ingredientName: 'Zwiebel',
          replacement: rep,
          kind: AlternativeChoiceKind.tryIt,
        );
    expect(ok, isFalse);
    expect(c.read(alternativeChoicesProvider).value!.map((e) => e.id), ['old']);
  });

  test('choose fails over an existing row: the old row is restored', () async {
    service.onFetch = (_) async => [row('old', choice: 'skip')];
    final c = make();
    await c.read(alternativeChoicesProvider.future);
    service.onUpsert = () async => throw Exception('boom');

    final ok = await c
        .read(alternativeChoicesProvider.notifier)
        .choose(
          ingredientId: 'i1',
          ingredientName: 'Zwiebel',
          replacement: rep,
          kind: AlternativeChoiceKind.tryIt,
        );
    expect(ok, isFalse);
    final list = c.read(alternativeChoicesProvider).value!;
    expect(list.single.id, 'old');
    expect(list.single.kind, AlternativeChoiceKind.skip);
  });

  test(
    'remove deletes the row; failure restores it and returns false',
    () async {
      service.onFetch = (_) async => [row('a'), row('b', ing: 'i2')];
      final c = make();
      await c.read(alternativeChoicesProvider.future);
      final n = c.read(alternativeChoicesProvider.notifier);

      expect(await n.remove('a'), isTrue);
      expect(service.deleted, ['a']);
      expect(c.read(alternativeChoicesProvider).value!.map((e) => e.id), ['b']);

      service.onDelete = (_) async => throw Exception('boom');
      expect(await n.remove('b'), isFalse);
      expect(c.read(alternativeChoicesProvider).value!.map((e) => e.id), ['b']);
    },
  );

  test(
    'a fetch finishing after a switch to user B does not show A\'s choices',
    () async {
      final heldA = Completer<List<Map<String, dynamic>>>();
      service.onFetch = (id) =>
          id == 'user-a' ? heldA.future : Future.value([row('b1', ing: 'i2')]);
      final c = make(userId: 'user-a');
      final sub = c.listen(alternativeChoicesProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);

      user.set(c, 'user-b');
      heldA.complete([row('a1')]);
      final list = await c.read(alternativeChoicesProvider.future);
      expect(list.map((e) => e.id), ['b1']);
    },
  );

  test('triedAlternatives lists only tryIt rows, newest first', () async {
    service.onFetch = (_) async => [
      row('new', ing: 'i1', at: '2026-11-27T12:00:00+00:00'),
      row('skip', ing: 'i2', choice: 'skip'),
      row('old', ing: 'i3', at: '2026-11-26T12:00:00+00:00'),
    ];
    final c = make();
    await c.read(alternativeChoicesProvider.future);
    expect(c.read(triedAlternativesProvider).map((e) => e.id), ['new', 'old']);
    expect(c.read(chosenAlternativesProvider), hasLength(3));
  });
}
