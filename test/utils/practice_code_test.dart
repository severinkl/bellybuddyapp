import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/utils/practice_code.dart';

/// Core's `NORMALIZE_VECTORS` (backend/tests/domain/test_dietitians.py),
/// copied one to one: app and core must agree on every entry.
const _normalizeVectors = <(String, String?)>[
  (' berger 7k2 ', 'BERGER-7K2'),
  ('berger7k2', 'BERGER-7K2'),
  ('BERGER-7K2', 'BERGER-7K2'),
  ('7K2', null),
  ('BERGER-7O2', null),
  ('', null),
  ('ber\tger\n7k2', 'BERGER-7K2'),
  ('BERGER--7K2', 'BERGER-7K2'),
  ('BER-GER7K2', 'BERGER-7K2'),
  ('BERGERX-7K2', null),
  ('BÄRGER-7K2', null),
  ('ßß-7K2', null),
  ('ﬁ-7K2', null),
  ('BERGER‑7K2', null),
  ('BERGER–7K2', null),
  ('BERGER 7K2', null),
  ('BERGER\x1c7K2', null),
];

void main() {
  group('normalizePracticeCode (core vectors)', () {
    for (final (raw, expected) in _normalizeVectors) {
      test('${Uri.encodeFull(raw)} -> $expected', () {
        expect(normalizePracticeCode(raw), expected);
      });
    }
  });

  group('normalizePracticeCode (more)', () {
    test('carriage return is stripped', () {
      expect(normalizePracticeCode('BERGER\r\n7K2'), 'BERGER-7K2');
    });
    test('a trailing newline does not slip past the full match', () {
      // Stripped anyway; a character kept after the code must fail.
      expect(normalizePracticeCode('BERGER-7K2.'), isNull);
      expect(normalizePracticeCode('BERGER-7K2\x0b'), isNull);
    });
    test('two letters is the shortest prefix', () {
      expect(normalizePracticeCode('ab7k2'), 'AB-7K2');
      expect(normalizePracticeCode('a7k2'), isNull);
    });
  });

  group('practiceCodeFromScan', () {
    test('the Connect URL', () {
      expect(
        practiceCodeFromScan('https://connect.bellybuddy.at/c/BERGER-7K2'),
        'BERGER-7K2',
      );
      expect(
        practiceCodeFromScan(' https://connect.bellybuddy.at/c/berger7k2 '),
        'BERGER-7K2',
      );
    });
    test('a bare code', () {
      expect(practiceCodeFromScan('BERGER-7K2'), 'BERGER-7K2');
      expect(practiceCodeFromScan('berger 7k2'), 'BERGER-7K2');
    });
    test('http is refused', () {
      expect(
        practiceCodeFromScan('http://connect.bellybuddy.at/c/BERGER-7K2'),
        isNull,
      );
    });
    test('another host is refused', () {
      expect(practiceCodeFromScan('https://evil.example/c/BERGER-7K2'), isNull);
      expect(
        practiceCodeFromScan(
          'https://connect.bellybuddy.at.evil.example/c/BERGER-7K2',
        ),
        isNull,
      );
    });
    test('another path, a query or a port is refused', () {
      expect(
        practiceCodeFromScan('https://connect.bellybuddy.at/x/BERGER-7K2'),
        isNull,
      );
      expect(
        practiceCodeFromScan('https://connect.bellybuddy.at/c/BERGER-7K2/x'),
        isNull,
      );
      expect(
        practiceCodeFromScan('https://connect.bellybuddy.at/c/BERGER-7K2?a=1'),
        isNull,
      );
      expect(
        practiceCodeFromScan('https://connect.bellybuddy.at:8443/c/BERGER-7K2'),
        isNull,
      );
    });
    test('garbage', () {
      expect(practiceCodeFromScan(''), isNull);
      expect(practiceCodeFromScan('hello world'), isNull);
      expect(practiceCodeFromScan('WIFI:S:home;T:WPA;P:secret;;'), isNull);
      expect(practiceCodeFromScan('https://connect.bellybuddy.at/c/'), isNull);
      expect(
        practiceCodeFromScan('https://connect.bellybuddy.at/c/7O2'),
        isNull,
      );
    });
  });
}
