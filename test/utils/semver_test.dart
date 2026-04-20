import 'package:belly_buddy/utils/semver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareSemver', () {
    test('equal versions return 0', () {
      expect(compareSemver('1.2.3', '1.2.3'), 0);
    });

    test('a less than b returns negative', () {
      expect(compareSemver('1.2.3', '1.2.4'), isNegative);
      expect(compareSemver('1.2.3', '1.3.0'), isNegative);
      expect(compareSemver('1.2.3', '2.0.0'), isNegative);
    });

    test('a greater than b returns positive', () {
      expect(compareSemver('1.2.4', '1.2.3'), isPositive);
      expect(compareSemver('1.3.0', '1.2.9'), isPositive);
      expect(compareSemver('2.0.0', '1.99.99'), isPositive);
    });

    test('build-number suffix is ignored', () {
      expect(compareSemver('1.2.3+5', '1.2.3+99'), 0);
      expect(compareSemver('1.2.3+5', '1.2.4+1'), isNegative);
    });

    test('missing segments default to zero', () {
      expect(compareSemver('1', '1.0.0'), 0);
      expect(compareSemver('1.2', '1.2.0'), 0);
      expect(compareSemver('1.2', '1.2.1'), isNegative);
    });
  });
}
