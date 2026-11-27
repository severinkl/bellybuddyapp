import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/models/product.dart';
import 'package:belly_buddy/services/product_service.dart';

import '../helpers/mocks.dart';
import '../helpers/supabase_mocks.dart';

void main() {
  late MockSupabaseClient client;
  late MockFunctionsClient functions;
  late ProductService service;

  setUp(() {
    client = MockSupabaseClient();
    functions = mockFunctions(client);
    service = ProductService(client);
  });

  void stubAnswer(Object? data) => when(
    () => functions.invoke(any(), body: any(named: 'body')),
  ).thenAnswer((_) async => FunctionResponse(status: 200, data: data));

  Map<dynamic, dynamic> sentBody() =>
      verify(
            () => functions.invoke(
              'product-lookup',
              body: captureAny(named: 'body'),
            ),
          ).captured.single
          as Map;

  test(
    'found: maps name to title, brand and ingredients with null ids',
    () async {
      stubAnswer({
        'found': true,
        'product': {
          'barcode': '4001234567890',
          'name': 'Testjoghurt',
          'brand': 'Testmarke',
          'ingredients': [
            {'name': 'Milch', 'ingredientId': 'i-1'},
            {'name': 'Zucker', 'ingredientId': null},
          ],
        },
      });

      final result = await service.lookup('4001234567890');

      final p = (result as ProductFound).product;
      expect(p.barcode, '4001234567890');
      expect(p.title, 'Testjoghurt');
      expect(p.brand, 'Testmarke');
      expect(p.ingredients.map((i) => i.name), ['Milch', 'Zucker']);
      expect(p.ingredients.map((i) => i.ingredientId), ['i-1', null]);
      expect(sentBody(), {'barcode': '4001234567890'});
    },
  );

  test('not found: ProductNotFound with the barcode', () async {
    stubAnswer({'found': false, 'barcode': '4001234567890'});

    final result = await service.lookup('4001234567890');

    expect((result as ProductNotFound).barcode, '4001234567890');
  });

  test('search: hits in order, brand may be null', () async {
    stubAnswer({
      'results': [
        {'barcode': '1', 'name': 'A', 'brand': 'X'},
        {'barcode': '2', 'name': 'B', 'brand': null},
      ],
    });

    final hits = await service.search('joghurt');

    expect(hits.map((h) => h.barcode), ['1', '2']);
    expect(hits.map((h) => h.name), ['A', 'B']);
    expect(hits.map((h) => h.brand), ['X', null]);
    expect(sentBody(), {'q': 'joghurt'});
  });

  test(
    '429 with body {error, code}: ProductException with core text',
    () async {
      when(() => functions.invoke(any(), body: any(named: 'body'))).thenThrow(
        const FunctionException(
          status: 429,
          details: {'error': 'Zu viele Anfragen.', 'code': 'rate_limited'},
        ),
      );

      await expectLater(
        service.lookup('4001234567890'),
        throwsA(
          isA<ProductException>()
              .having((e) => e.status, 'status', 429)
              .having((e) => e.message, 'message', 'Zu viele Anfragen.'),
        ),
      );
    },
  );

  test('a non-JSON error body: ProductException with message null', () async {
    when(
      () => functions.invoke(any(), body: any(named: 'body')),
    ).thenThrow(const FunctionException(status: 502, details: 'Bad Gateway'));

    await expectLater(
      service.search('x'),
      throwsA(
        isA<ProductException>()
            .having((e) => e.status, 'status', 502)
            .having((e) => e.message, 'message', isNull),
      ),
    );
  });

  test('an unreadable 200 answer: ProductException()', () async {
    for (final data in <Object?>[
      {'nope': true},
      'text',
      null,
      {
        'found': true,
        'product': {'name': 1},
      },
    ]) {
      stubAnswer(data);
      await expectLater(
        service.lookup('1'),
        throwsA(
          isA<ProductException>()
              .having((e) => e.status, 'status', isNull)
              .having((e) => e.message, 'message', isNull),
        ),
        reason: '$data',
      );
    }
    stubAnswer({'found': true});
    await expectLater(service.search('x'), throwsA(isA<ProductException>()));
  });
}
