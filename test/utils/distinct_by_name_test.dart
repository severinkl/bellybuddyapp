import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/utils/distinct_by_name.dart';

void main() {
  test('keeps the first of each name, case and spaces ignored', () {
    final kept = distinctByName<(String, String?)>([
      ('Reis', '200 g'),
      ('Salz', null),
      (' reis ', '1 Tasse'),
      ('  ', '1 EL'),
      ('SALZ', '1 Prise'),
      ('Öl', '2 EL'),
    ], (item) => item.$1);

    // Each kept item brings what it carries, so amounts stay aligned.
    expect(kept, [('Reis', '200 g'), ('Salz', null), ('Öl', '2 EL')]);
  });

  test('plain names', () {
    expect(distinctByName(['A', 'a', 'B'], (n) => n), ['A', 'B']);
    expect(distinctByName(<String>[], (n) => n), isEmpty);
  });
}
