import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/models/feedback.dart';
import 'package:belly_buddy/services/feedback_service.dart';

import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

const _ctx = FeedbackContext(
  appVersion: '1.3.0',
  platform: 'ios',
  osVersion: '18.1',
);

const _tooMany =
    "Du hast heute schon 5-mal Feedback geschickt. Morgen geht's wieder.";

void main() {
  late MockSupabaseClient client;
  late MockFunctionsClient functions;
  late FeedbackService service;

  Future<void> send() => service.send(
    category: FeedbackCategory.praise,
    message: 'Super App',
    replyWanted: true,
    context: _ctx,
  );

  setUp(() {
    client = MockSupabaseClient();
    functions = mockFunctions(client);
    service = FeedbackService(client);
  });

  test('send posts the contract body', () async {
    when(() => functions.invoke(any(), body: any(named: 'body'))).thenAnswer(
      (_) async => const FunctionResponse(data: {'ok': true}, status: 200),
    );

    await send();

    verify(
      () => functions.invoke(
        'feedback',
        body: {
          'category': 'praise',
          'message': 'Super App',
          'reply_wanted': true,
          'app_version': '1.3.0',
          'platform': 'ios',
          'os_version': '18.1',
        },
      ),
    ).called(1);
  });

  test('send maps a 429 to FeedbackException with the server message', () {
    when(() => functions.invoke(any(), body: any(named: 'body'))).thenThrow(
      const FunctionException(status: 429, details: {'error': _tooMany}),
    );

    expect(
      send(),
      throwsA(
        isA<FeedbackException>()
            .having((e) => e.status, 'status', 429)
            .having((e) => e.message, 'message', _tooMany),
      ),
    );
  });

  test('send maps a text error body to a status without message', () {
    when(
      () => functions.invoke(any(), body: any(named: 'body')),
    ).thenThrow(const FunctionException(status: 502, details: 'Bad Gateway'));

    expect(
      send(),
      throwsA(
        isA<FeedbackException>()
            .having((e) => e.status, 'status', 502)
            .having((e) => e.message, 'message', isNull),
      ),
    );
  });

  test('send maps a socket error to FeedbackException without message', () {
    when(
      () => functions.invoke(any(), body: any(named: 'body')),
    ).thenThrow(const SocketException('Super App unreachable'));

    expect(
      send(),
      throwsA(
        isA<FeedbackException>()
            .having((e) => e.status, 'status', isNull)
            .having((e) => e.message, 'message', isNull),
      ),
    );
  });

  group('systemLabel', () {
    test('iOS', () {
      expect(
        const FeedbackContext(
          appVersion: '1',
          platform: 'ios',
          osVersion: '18.1',
        ).systemLabel,
        'iOS 18.1',
      );
    });

    test('Android', () {
      expect(
        const FeedbackContext(
          appVersion: '1',
          platform: 'android',
          osVersion: '14',
        ).systemLabel,
        'Android 14',
      );
    });
  });

  group('send never logs the message', () {
    late DebugPrintCallback original;
    late List<String> logs;

    setUp(() {
      original = debugPrint;
      logs = [];
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    });
    tearDown(() => debugPrint = original);

    test('on success', () async {
      when(() => functions.invoke(any(), body: any(named: 'body'))).thenAnswer(
        (_) async => const FunctionResponse(data: {'ok': true}, status: 200),
      );
      await send();
      expect(logs, isNotEmpty);
      expect(logs.join('\n'), isNot(contains('Super App')));
    });

    test('on failures', () async {
      when(() => functions.invoke(any(), body: any(named: 'body'))).thenThrow(
        const FunctionException(status: 429, details: {'error': _tooMany}),
      );
      await expectLater(send(), throwsA(isA<FeedbackException>()));
      when(
        () => functions.invoke(any(), body: any(named: 'body')),
      ).thenThrow(const SocketException('Super App'));
      await expectLater(send(), throwsA(isA<FeedbackException>()));
      final text = logs.join('\n');
      expect(text, contains('429'));
      expect(text, isNot(contains('Super App')));
      expect(text, isNot(contains('praise')));
    });
  });
}
