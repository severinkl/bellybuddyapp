import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/services/edge_function_service.dart';

import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

void main() {
  late MockSupabaseClient client;
  late MockFunctionsClient functions;
  late EdgeFunctionService service;

  setUp(() {
    client = MockSupabaseClient();
    functions = mockFunctions(client);
    service = EdgeFunctionService(client);
  });

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  group('EdgeFunctionService.invoke', () {
    test(
      'returns Map response as-is when data is Map<String, dynamic>',
      () async {
        final data = <String, dynamic>{'result': 'ok', 'count': 3};
        when(
          () => functions.invoke(any(), body: any(named: 'body')),
        ).thenAnswer((_) async => FunctionResponse(data: data, status: 200));

        final result = await service.invoke('my-function', body: {'x': 1});

        expect(result, data);
      },
    );

    test('wraps non-Map response in {"data": response}', () async {
      const rawData = 'plain string response';
      when(
        () => functions.invoke(any(), body: any(named: 'body')),
      ).thenAnswer((_) async => FunctionResponse(data: rawData, status: 200));

      final result = await service.invoke('my-function');

      expect(result, {'data': rawData});
    });

    test('propagates error thrown by functions.invoke', () async {
      // The service always passes body: (even if null), so stub with named arg.
      when(() => functions.invoke(any(), body: any(named: 'body'))).thenThrow(
        const FunctionException(status: 500, details: 'server error'),
      );

      await expectLater(
        service.invoke('failing-function'),
        throwsA(isA<FunctionException>()),
      );
    });
  });
}
