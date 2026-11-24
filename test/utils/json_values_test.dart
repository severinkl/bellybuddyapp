import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/utils/json_values.dart';

void main() {
  test('jsonStrings: the strings of a list', () {
    expect(jsonStrings(['a', 1, null, 'b']), ['a', 'b']);
    expect(jsonStrings('a'), isEmpty);
    expect(jsonStrings(null), isEmpty);
  });

  test('trimmedOrNull: trimmed, blank and non-strings as null', () {
    expect(trimmedOrNull('  2 EL '), '2 EL');
    expect(trimmedOrNull('   '), isNull);
    expect(trimmedOrNull(''), isNull);
    expect(trimmedOrNull(25), isNull);
    expect(trimmedOrNull(null), isNull);
  });
}
