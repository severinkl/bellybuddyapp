import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/utils/function_exception_utils.dart';

FunctionException _ex(Object? details) =>
    FunctionException(status: 400, details: details);

void main() {
  group('errorMessage', () {
    test('returns the error text', () {
      expect(_ex({'error': 'Zu lang'}).errorMessage(), 'Zu lang');
    });

    test('null for a non-map body, a missing, empty or non-string error', () {
      expect(_ex('<html>').errorMessage(), isNull);
      expect(_ex(null).errorMessage(), isNull);
      expect(_ex({'message': 'x'}).errorMessage(), isNull);
      expect(_ex({'error': ''}).errorMessage(), isNull);
      expect(_ex({'error': 3}).errorMessage(), isNull);
    });

    test('orMessage falls back to message', () {
      expect(_ex({'message': 'x'}).errorMessage(orMessage: true), 'x');
      expect(
        _ex({'error': 'e', 'message': 'x'}).errorMessage(orMessage: true),
        'e',
      );
    });
  });
}
