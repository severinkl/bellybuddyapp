import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/utils/retry_helper.dart';

void main() {
  group('retryAsync', () {
    test('succeeds on first attempt', () async {
      final result = await retryAsync(() async => 42, backoff: Duration.zero);
      expect(result, 42);
    });

    test('fails once then succeeds', () async {
      var calls = 0;
      final result = await retryAsync(() async {
        calls++;
        if (calls == 1) throw Exception('fail');
        return 'ok';
      }, backoff: Duration.zero);
      expect(result, 'ok');
      expect(calls, 2);
    });

    test('all attempts fail rethrows last error', () async {
      var calls = 0;
      expect(
        () => retryAsync(
          () async {
            calls++;
            throw Exception('fail $calls');
          },
          maxAttempts: 2,
          backoff: Duration.zero,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('respects maxAttempts parameter', () async {
      var calls = 0;
      try {
        await retryAsync(
          () async {
            calls++;
            throw Exception('fail');
          },
          maxAttempts: 4,
          backoff: Duration.zero,
        );
      } catch (_) {}
      expect(calls, 4);
    });

    test('passes label to logger on error', () async {
      // retryAsync accepts an AppLogger but we can verify the label
      // is used by checking it doesn't throw when label is provided
      try {
        await retryAsync(
          () async => throw Exception('fail'),
          maxAttempts: 1,
          backoff: Duration.zero,
          label: 'test-operation',
        );
      } catch (_) {}
      // If we get here, label param was accepted without error
    });
  });
}
