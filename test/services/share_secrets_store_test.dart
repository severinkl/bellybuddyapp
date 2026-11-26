import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/models/data_share.dart';
import 'package:belly_buddy/services/share_secrets_store.dart';

void main() {
  String? uid = 'user-a';
  late ShareSecretsStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'user-a';
    store = ShareSecretsStore(userId: () => uid);
  });

  const secret = ShareSecret(link: 'https://x.example/s/abc', code: '123456');

  test('saves and reads a secret', () async {
    await store.save('s1', secret);
    final read = await store.read('s1');
    expect(read?.link, secret.link);
    expect(read?.code, secret.code);
  });

  test('read of an unknown share is null', () async {
    expect(await store.read('nope'), isNull);
  });

  test('remove deletes one secret only', () async {
    await store.save('s1', secret);
    await store.save('s2', secret);
    await store.remove('s1');
    expect(await store.read('s1'), isNull);
    expect(await store.read('s2'), isNotNull);
  });

  test('two accounts never see each other', () async {
    await store.save('s1', secret);
    await store.rememberDisplayName('Dr. A');
    uid = 'user-b';
    expect(await store.read('s1'), isNull);
    expect(await store.lastDisplayName(), isNull);
  });

  test(
    'clear removes all secrets and the name of the current user only',
    () async {
      await store.save('s1', secret);
      await store.save('s2', secret);
      await store.rememberDisplayName('Dr. A');
      uid = 'user-b';
      await store.save('s1', secret);
      await store.rememberDisplayName('Dr. B');
      uid = 'user-a';
      await store.clear();
      expect(await store.read('s1'), isNull);
      expect(await store.read('s2'), isNull);
      expect(await store.lastDisplayName(), isNull);
      uid = 'user-b';
      expect(await store.read('s1'), isNotNull);
      expect(await store.lastDisplayName(), 'Dr. B');
    },
  );

  test('remembers the display name', () async {
    expect(await store.lastDisplayName(), isNull);
    await store.rememberDisplayName('Dr. Muster');
    expect(await store.lastDisplayName(), 'Dr. Muster');
  });

  test('signed out: reads null, writes nothing', () async {
    uid = null;
    await store.save('s1', secret);
    expect(await store.read('s1'), isNull);
    await store.rememberDisplayName('x');
    expect(await store.lastDisplayName(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });
}
