import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/models/data_share.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/shares_provider.dart';
import 'package:belly_buddy/services/share_secrets_store.dart';
import 'package:belly_buddy/services/share_service.dart';

import '../helpers/share_fakes.dart';

void main() {
  late FakeShareService service;
  late ProviderContainer container;
  late ShareSecretsStore store;

  const newShare = NewShare(
    displayName: 'Dr. B',
    period: SharePeriod.days30,
    validDays: 30,
    meals: true,
    drinks: true,
    gut: true,
    toilet: true,
    patterns: false,
    photos: false,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = FakeShareService([testShare()]);
    container = ProviderContainer.test(
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        shareServiceProvider.overrideWithValue(service),
      ],
    );
    store = container.read(shareSecretsStoreProvider);
  });

  test('loads the shares', () async {
    final shares = await container.read(sharesProvider.future);
    expect(shares.map((s) => s.id), ['s1']);
  });

  test('nobody signed in: no shares, no call', () async {
    final out = ProviderContainer.test(
      overrides: [
        currentUserIdProvider.overrideWithValue(null),
        shareServiceProvider.overrideWithValue(service),
      ],
    );
    expect(await out.read(sharesProvider.future), isEmpty);
    expect(service.listCalls, 0);
  });

  test('create stores the secret, remembers the name and reloads', () async {
    await container.read(sharesProvider.future);
    final created = await container
        .read(sharesProvider.notifier)
        .create(newShare);

    expect(created.id, 'new1');
    final secret = await store.read('new1');
    expect(secret?.code, '482913');
    expect(secret?.link, 'https://example.test/s/abc');
    expect(await store.lastDisplayName(), 'Dr. B');
    expect(container.read(sharesProvider).value!.map((s) => s.id), [
      'new1',
      's1',
    ]);
  });

  test('a failing create stores nothing', () async {
    await container.read(sharesProvider.future);
    service.failCreate = true;
    await expectLater(
      container.read(sharesProvider.notifier).create(newShare),
      throwsA(isA<ShareException>()),
    );
    expect(await store.read('new1'), isNull);
    expect(await store.lastDisplayName(), isNull);
  });

  test('end reloads and removes the secret', () async {
    await container.read(sharesProvider.future);
    await store.save('s1', const ShareSecret(link: 'l', code: 'c'));

    await container.read(sharesProvider.notifier).end('s1');

    expect(service.ended, ['s1']);
    expect(await store.read('s1'), isNull);
    expect(container.read(sharesProvider).value!.single.revokedAt, isNotNull);
  });

  test('a failing end leaves the list and the secret as they were', () async {
    await container.read(sharesProvider.future);
    await store.save('s1', const ShareSecret(link: 'l', code: 'c'));
    service.failEnd = true;

    await expectLater(
      container.read(sharesProvider.notifier).end('s1'),
      throwsA(isA<ShareException>()),
    );

    expect(await store.read('s1'), isNotNull);
    final state = container.read(sharesProvider);
    expect(state.hasError, isFalse);
    expect(state.value!.single.revokedAt, isNull);
  });

  test('a failing reload after end keeps the list shown', () async {
    await container.read(sharesProvider.future);
    service.failList = true;
    await container.read(sharesProvider.notifier).end('s1');
    expect(container.read(sharesProvider).value, isNotNull);
  });

  test(
    'refresh tells whether it loaded, and keeps the list on failure',
    () async {
      await container.read(sharesProvider.future);
      final notifier = container.read(sharesProvider.notifier);
      expect(await notifier.refresh(), isTrue);

      service.failList = true;
      expect(await notifier.refresh(), isFalse);
      final state = container.read(sharesProvider);
      expect(state.hasError, isFalse);
      expect(state.value!.map((s) => s.id), ['s1']);
    },
  );

  test('a refresh that ends after the user changed writes nothing', () async {
    final id = NotifierProvider<_Id, String?>(_Id.new);
    final gated = _GatedService([testShare()]);
    final c = ProviderContainer.test(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(id)),
        shareServiceProvider.overrideWithValue(gated),
      ],
    );
    c.read(id.notifier).set('u1');
    await c.read(sharesProvider.future);

    // u1's refresh is on its way when the account changes.
    final gate = gated.gate = Completer<void>();
    final pending = c.read(sharesProvider.notifier).refresh();
    c.read(id.notifier).set('u2');
    gated.shares = [testShare(id: 'u2-share')];
    expect((await c.read(sharesProvider.future)).map((s) => s.id), [
      'u2-share',
    ]);

    gate.complete();
    await pending;
    expect(c.read(sharesProvider).value!.map((s) => s.id), ['u2-share']);
  });

  test('an older refresh answering last does not undo a newer one', () async {
    final gated = _GatedService([testShare()]);
    final c = ProviderContainer.test(
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        shareServiceProvider.overrideWithValue(gated),
      ],
    );
    await c.read(sharesProvider.future);
    final notifier = c.read(sharesProvider.notifier);

    // A slow pull to refresh, then the share is ended.
    final gate = gated.gate = Completer<void>();
    final slow = notifier.refresh();
    await notifier.end('s1');
    expect(c.read(sharesProvider).value!.single.revokedAt, isNotNull);

    gate.complete();
    await slow;
    expect(c.read(sharesProvider).value!.single.revokedAt, isNotNull);
  });

  test('a create during the first load is not undone by that load', () async {
    final gated = _GatedService([testShare()]);
    final c = ProviderContainer.test(
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        shareServiceProvider.overrideWithValue(gated),
      ],
    );
    // The first load is slow; a create finishes before it.
    final gate = gated.gate = Completer<void>();
    final first = c.read(sharesProvider.future);
    final creating = c.read(sharesProvider.notifier).create(newShare);
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await first;
    await creating;
    expect(c.read(sharesProvider).value!.map((s) => s.id), ['new1', 's1']);
  });

  group('dietitian connections', () {
    const terms = DietitianShareTerms(
      displayName: 'Anna',
      period: SharePeriod.days30,
      duration: ShareDuration.open,
      meals: false,
      drinks: true,
      gut: true,
      toilet: true,
      patterns: false,
      photos: false,
    );

    test('updateTerms reloads the list', () async {
      await container.read(sharesProvider.future);
      await container.read(sharesProvider.notifier).updateTerms('s1', terms);
      expect(service.updated.single.$1, 's1');
      expect(container.read(sharesProvider).value!.single.shareMeals, isFalse);
    });

    test('a failing updateTerms throws and leaves the state', () async {
      await container.read(sharesProvider.future);
      service.failUpdate = true;
      await expectLater(
        container.read(sharesProvider.notifier).updateTerms('s1', terms),
        throwsA(isA<ShareException>()),
      );
      final state = container.read(sharesProvider);
      expect(state.hasError, isFalse);
      expect(state.value!.single.shareMeals, isTrue);
    });

    test('connect reloads, remembers the name and returns the id', () async {
      await container.read(sharesProvider.future);
      final id = await container
          .read(sharesProvider.notifier)
          .connect('BERGER-7K2', terms);
      expect(id, 'c1');
      expect(container.read(sharesProvider).value!.first.id, 'c1');
      expect(await store.lastDisplayName(), 'Anna');
    });

    test('a failing connect throws and changes nothing', () async {
      await container.read(sharesProvider.future);
      service.failConnect = true;
      await expectLater(
        container.read(sharesProvider.notifier).connect('BERGER-7K2', terms),
        throwsA(isA<ShareException>()),
      );
      expect(container.read(sharesProvider).value!.length, 1);
      expect(await store.lastDisplayName(), isNull);
    });

    test('activeDietitianCount counts active dietitian shares only', () async {
      service.shares = [
        testShare(id: 'link'),
        testDietitianShare(id: 'a'),
        testDietitianShare(id: 'b', revokedAt: DateTime(2026, 11, 20)),
        testDietitianShare(
          id: 'c',
          dietitian: testCard(blockedAt: DateTime(2026, 11, 1)),
        ),
        testDietitianShare(id: 'd', expiresAt: DateTime(2026, 11, 1)),
        testDietitianShare(id: 'e', dietitianId: null),
      ];
      final c = ProviderContainer.test(
        overrides: [
          currentUserIdProvider.overrideWithValue('u1'),
          shareServiceProvider.overrideWithValue(service),
          buddyClockProvider.overrideWithValue(() => DateTime(2026, 11, 26)),
        ],
      );
      await c.read(sharesProvider.future);
      expect(c.read(activeDietitianCountProvider), 2);
    });
  });

  group('local storage failing', () {
    setUp(() {
      container = ProviderContainer.test(
        overrides: [
          currentUserIdProvider.overrideWithValue('u1'),
          shareServiceProvider.overrideWithValue(service),
          shareSecretsStoreProvider.overrideWithValue(_BrokenStore()),
        ],
      );
    });

    test('create still returns the created share and lists it', () async {
      await container.read(sharesProvider.future);
      final created = await container
          .read(sharesProvider.notifier)
          .create(newShare);
      expect(created.id, 'new1');
      expect(container.read(sharesProvider).value!.map((s) => s.id), [
        'new1',
        's1',
      ]);
    });

    test('end still ends and reloads', () async {
      await container.read(sharesProvider.future);
      await container.read(sharesProvider.notifier).end('s1');
      expect(service.ended, ['s1']);
      expect(container.read(sharesProvider).value!.single.revokedAt, isNotNull);
    });
  });

  test('a pending secret does not outlive the signed-in user', () {
    final id = NotifierProvider<_Id, String?>(_Id.new);
    final c = ProviderContainer.test(
      overrides: [currentUserIdProvider.overrideWith((ref) => ref.watch(id))],
    );
    c.read(id.notifier).set('u1');
    c
        .read(justCreatedShareProvider.notifier)
        .set(const ShareSecret(link: 'l', code: 'c'));
    expect(c.read(justCreatedShareProvider), isNotNull);

    c.read(id.notifier).set(null);
    expect(c.read(justCreatedShareProvider), isNull);
  });

  test('the badge shows until marked, and stays marked', () async {
    expect(await container.read(shareRowBadgeProvider.future), isTrue);
    await container.read(shareRowBadgeProvider.notifier).markTapped();
    expect(container.read(shareRowBadgeProvider).value, isFalse);

    final again = ProviderContainer.test();
    expect(await again.read(shareRowBadgeProvider.future), isFalse);
  });
}

class _Id extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
}

class _BrokenStore extends ShareSecretsStore {
  _BrokenStore() : super(userId: () => 'u1');
  @override
  Future<void> save(String shareId, ShareSecret secret) =>
      throw Exception('disk full');
  @override
  Future<void> remove(String shareId) => throw Exception('disk full');
  @override
  Future<void> rememberDisplayName(String name) => throw Exception('disk full');
}

/// Answers with the shares it had when called; the call that finds [gate]
/// set waits for it (and clears it).
class _GatedService extends FakeShareService {
  _GatedService(super.shares);
  Completer<void>? gate;
  @override
  Future<List<DataShare>> list() async {
    final answer = await super.list();
    final g = gate;
    gate = null;
    if (g != null) await g.future;
    return answer;
  }
}
