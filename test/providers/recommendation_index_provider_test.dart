// ignore_for_file: invalid_use_of_internal_member
import 'package:belly_buddy/providers/recommendation_index_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/riverpod_helpers.dart';

void main() {
  group('recommendationIndexProvider', () {
    test('initial value is 0', () {
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(recommendationIndexProvider), 0);
    });

    test('set(n) updates state to n', () {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(recommendationIndexProvider.notifier).set(5);
      expect(container.read(recommendationIndexProvider), 5);

      container.read(recommendationIndexProvider.notifier).set(0);
      expect(container.read(recommendationIndexProvider), 0);
    });
  });
}
