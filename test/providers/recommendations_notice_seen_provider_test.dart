import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/providers/recommendation_provider.dart';

void main() {
  test('recommendationsNoticeSeenProvider defaults to false', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(recommendationsNoticeSeenProvider), isFalse);
  });

  test('flag can be flipped to true within a container (session)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(recommendationsNoticeSeenProvider.notifier).state = true;

    expect(container.read(recommendationsNoticeSeenProvider), isTrue);
  });
}
