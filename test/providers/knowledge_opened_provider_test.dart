import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/providers/knowledge_opened_provider.dart';

import '../helpers/riverpod_helpers.dart';

Uri _link(int i) => Uri.parse('https://www.myfodmap.at/artikel-$i');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('markOpened stores newest last, keeps 50, survives a rebuild', () async {
    final user = SwitchableUserId('u1');
    var c = ProviderContainer.test(overrides: [user.override]);
    expect(await c.read(knowledgeOpenedProvider.future), isEmpty);

    final notifier = c.read(knowledgeOpenedProvider.notifier);
    for (var i = 0; i < 52; i++) {
      await notifier.markOpened(_link(i));
    }
    // Opening one again moves it to the end.
    await notifier.markOpened(_link(10));

    final expected = [
      for (var i = 2; i < 52; i++)
        if (i != 10) _link(i).toString(),
      _link(10).toString(),
    ];
    expect(c.read(knowledgeOpenedProvider).value!.toList(), expected);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('knowledge_opened_u1'), expected);

    c.dispose();
    c = ProviderContainer.test(overrides: [user.override]);
    expect((await c.read(knowledgeOpenedProvider.future)).toList(), expected);
  });

  test('opened list is per user', () async {
    final user = SwitchableUserId('a');
    final c = ProviderContainer.test(overrides: [user.override]);
    c.listen(knowledgeOpenedProvider, (_, _) {});
    await c.read(knowledgeOpenedProvider.future);
    await c.read(knowledgeOpenedProvider.notifier).markOpened(_link(1));
    expect(await c.read(knowledgeOpenedProvider.future), {_link(1).toString()});

    user.set(c, 'b');
    expect(await c.read(knowledgeOpenedProvider.future), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('knowledge_opened_b'), isNull);

    user.set(c, null);
    expect(await c.read(knowledgeOpenedProvider.future), isEmpty);
    // Signed out, nothing is stored.
    await c.read(knowledgeOpenedProvider.notifier).markOpened(_link(2));
    expect(await c.read(knowledgeOpenedProvider.future), isEmpty);

    user.set(c, 'a');
    expect(await c.read(knowledgeOpenedProvider.future), {_link(1).toString()});
  });

  test('two markOpened calls before the load completes both land', () async {
    final c = ProviderContainer.test(
      overrides: [SwitchableUserId('u1').override],
    );
    c.listen(knowledgeOpenedProvider, (_, _) {});
    final notifier = c.read(knowledgeOpenedProvider.notifier);
    await Future.wait([
      notifier.markOpened(_link(1)),
      notifier.markOpened(_link(2)),
    ]);
    final expected = [_link(1).toString(), _link(2).toString()];
    expect(c.read(knowledgeOpenedProvider).value!.toList(), expected);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('knowledge_opened_u1'), expected);
  });
}
