import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/buddy_welcome_provider.dart';

/// The signed-in user's id, switchable.
class _UserId extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void set(String? id) => state = id;
}

final _userIdProvider = NotifierProvider<_UserId, String?>(_UserId.new);

void main() {
  ProviderContainer makeContainer() => ProviderContainer.test(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(_userIdProvider)),
    ],
  );

  test('take returns the pending line once', () {
    final c = makeContainer();
    final welcome = c.read(buddyWelcomeProvider.notifier);

    welcome.set(BuddyWelcomeNotifier.line);
    expect(welcome.take(), BuddyWelcomeNotifier.line);
    expect(welcome.take(), isNull);
  });

  for (final next in [null, 'u2']) {
    test('a welcome never taken is dropped when the user changes to $next', () {
      final c = makeContainer();
      c.read(buddyWelcomeProvider.notifier).set(BuddyWelcomeNotifier.line);

      c.read(_userIdProvider.notifier).set(next);

      expect(c.read(buddyWelcomeProvider), isNull);
    });
  }
}
