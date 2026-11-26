import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/models/data_share.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
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

  test('the badge shows until marked, and stays marked', () async {
    expect(await container.read(shareRowBadgeProvider.future), isTrue);
    await container.read(shareRowBadgeProvider.notifier).markTapped();
    expect(container.read(shareRowBadgeProvider).value, isFalse);

    final again = ProviderContainer.test();
    expect(await again.read(shareRowBadgeProvider.future), isFalse);
  });
}
