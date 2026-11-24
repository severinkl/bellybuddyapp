import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/utils/german_list.dart';

void main() {
  test('joins with commas and „und" before the last', () {
    expect(joinGerman([]), '');
    expect(joinGerman(['A']), 'A');
    expect(joinGerman(['A', 'B']), 'A und B');
    expect(joinGerman(['A', 'B', 'C']), 'A, B und C');
  });

  test('germanOrder sorts umlauts with their vowel, ß as ss', () {
    final keys = ['zwiebel', 'äpfel', 'birne', 'apfel', 'maße', 'masse'];
    keys.sort(germanOrder);
    expect(keys, ['apfel', 'äpfel', 'birne', 'masse', 'maße', 'zwiebel']);
    // Total: equal when folded, still by code unit, whatever the input order.
    expect(germanOrder('maße', 'masse'), greaterThan(0));
    expect(germanOrder('masse', 'maße'), lessThan(0));
    expect(germanOrder('apfel', 'apfel'), 0);
  });
}
