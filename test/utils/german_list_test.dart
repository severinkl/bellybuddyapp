import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/utils/german_list.dart';

void main() {
  test('joins with commas and „und" before the last', () {
    expect(joinGerman([]), '');
    expect(joinGerman(['A']), 'A');
    expect(joinGerman(['A', 'B']), 'A und B');
    expect(joinGerman(['A', 'B', 'C']), 'A, B und C');
  });
}
