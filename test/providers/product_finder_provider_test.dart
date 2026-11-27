import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/models/product.dart';
import 'package:belly_buddy/providers/product_finder_provider.dart';
import 'package:belly_buddy/services/product_service.dart';

/// Answers each call with the next completer the test completes.
class _FakeProductService implements ProductService {
  final lookups = <String>[];
  final searches = <String>[];
  final lookupAnswers = <Completer<ProductLookup>>[];
  final searchAnswers = <Completer<List<ProductHit>>>[];

  @override
  Future<ProductLookup> lookup(String barcode) {
    lookups.add(barcode);
    final c = Completer<ProductLookup>();
    lookupAnswers.add(c);
    return c.future;
  }

  @override
  Future<List<ProductHit>> search(String query) {
    searches.add(query);
    final c = Completer<List<ProductHit>>();
    searchAnswers.add(c);
    return c.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _product = ProductPrefill(
  barcode: '4000000000013',
  title: 'Testjoghurt',
  brand: 'Testmarke',
  ingredients: [ProductIngredient(name: 'Milch')],
);

void main() {
  late _FakeProductService service;
  late ProviderContainer container;

  setUp(() {
    service = _FakeProductService();
    container = ProviderContainer.test(
      overrides: [productServiceProvider.overrideWithValue(service)],
    );
    // autoDispose: keep it alive for the test.
    container.listen(productFinderProvider, (_, _) {});
  });

  ProductFinderNotifier notifier() =>
      container.read(productFinderProvider.notifier);
  ProductFinderState state() => container.read(productFinderProvider);

  test('starts scanning', () {
    expect(state(), isA<Scanning>());
  });

  test('a barcode is looked up: LookingUp, then Found', () async {
    expect(notifier().onBarcode('4000000000013'), isTrue);
    expect(state(), isA<LookingUp>());
    expect(service.lookups, ['4000000000013']);

    service.lookupAnswers.single.complete(ProductFound(_product));
    await pumpEventQueue();

    expect((state() as Found).product, same(_product));
  });

  test('a second barcode while not scanning is ignored', () async {
    notifier().onBarcode('4000000000013');
    expect(notifier().onBarcode('4000000000020'), isFalse);
    service.lookupAnswers.single.complete(ProductFound(_product));
    await pumpEventQueue();
    expect(notifier().onBarcode('4000000000020'), isFalse);
    expect(service.lookups, ['4000000000013']);
  });

  test('not found carries the barcode', () async {
    notifier().onBarcode('4000000000013');
    service.lookupAnswers.single.complete(ProductNotFound('4000000000013'));
    await pumpEventQueue();
    expect((state() as NotFound).barcode, '4000000000013');
  });

  test(
    'search: Searching, then the hits; a blank query does nothing',
    () async {
      notifier().search('   ');
      expect(service.searches, isEmpty);
      expect(state(), isA<Scanning>());

      notifier().search(' Joghurt ');
      expect(state(), isA<Searching>());
      expect(service.searches, ['Joghurt']);
      const hit = ProductHit(barcode: '4000000000013', name: 'Testjoghurt');
      service.searchAnswers.single.complete([hit]);
      await pumpEventQueue();

      expect((state() as SearchResults).hits, [hit]);
    },
  );

  test('pick looks the hit barcode up', () async {
    notifier().search('Joghurt');
    service.searchAnswers.single.complete([
      const ProductHit(barcode: '4000000000013', name: 'Testjoghurt'),
    ]);
    await pumpEventQueue();

    notifier().pick((state() as SearchResults).hits.single);
    expect(state(), isA<LookingUp>());
    expect(service.lookups, ['4000000000013']);
  });

  test('a failure with core text shows it, retry repeats the call', () async {
    notifier().onBarcode('4000000000013');
    service.lookupAnswers.single.completeError(
      const ProductException(status: 429, message: 'Zu viele Anfragen.'),
    );
    await pumpEventQueue();
    expect((state() as Failed).message, 'Zu viele Anfragen.');

    notifier().retry();
    expect(state(), isA<LookingUp>());
    expect(service.lookups, ['4000000000013', '4000000000013']);
    service.lookupAnswers.last.complete(ProductFound(_product));
    await pumpEventQueue();
    expect(state(), isA<Found>());
  });

  test(
    'a failure without text shows the fallback; retry repeats a search',
    () async {
      notifier().search('Joghurt');
      service.searchAnswers.single.completeError(const ProductException());
      await pumpEventQueue();
      expect(
        (state() as Failed).message,
        'Das hat gerade nicht geklappt. Versuch es bitte nochmal.',
      );

      notifier().retry();
      expect(state(), isA<Searching>());
      expect(service.searches, ['Joghurt', 'Joghurt']);
    },
  );

  test('reset goes back to scanning and drops a late answer', () async {
    notifier().onBarcode('4000000000013');
    notifier().reset();
    expect(state(), isA<Scanning>());

    service.lookupAnswers.single.complete(ProductFound(_product));
    await pumpEventQueue();
    expect(state(), isA<Scanning>());
  });

  test('a newer search wins over an older one', () async {
    notifier().search('Joghurt');
    notifier().search('Käse');
    service.searchAnswers.last.complete(const []);
    await pumpEventQueue();
    service.searchAnswers.first.complete([
      const ProductHit(barcode: '4000000000013', name: 'Testjoghurt'),
    ]);
    await pumpEventQueue();
    expect((state() as SearchResults).hits, isEmpty);
  });
}
