import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/utils/title_color.dart';

void main() {
  group('pastelForTitle', () {
    test('is deterministic across calls for the same input', () {
      expect(
        pastelForTitle('Curry mit Reis'),
        pastelForTitle('Curry mit Reis'),
      );
    });

    test('produces different colors for different titles', () {
      final a = pastelForTitle('Curry mit Reis');
      final b = pastelForTitle('Pizza Margherita');
      expect(a, isNot(equals(b)));
    });

    test('handles the empty string without throwing', () {
      expect(() => pastelForTitle(''), returnsNormally);
      expect(pastelForTitle(''), isA<Color>());
    });
  });
}
