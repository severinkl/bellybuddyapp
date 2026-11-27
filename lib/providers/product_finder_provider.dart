import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../services/product_service.dart';

/// What the product sheet shows.
sealed class ProductFinderState {
  const ProductFinderState();
}

/// The camera looks for a barcode.
final class Scanning extends ProductFinderState {
  const Scanning();
}

/// A search runs.
final class Searching extends ProductFinderState {
  const Searching();
}

/// The hits of the last search (maybe none).
final class SearchResults extends ProductFinderState {
  const SearchResults(this.hits);

  final List<ProductHit> hits;
}

/// A barcode is being looked up.
final class LookingUp extends ProductFinderState {
  const LookingUp();
}

final class Found extends ProductFinderState {
  const Found(this.product);

  final ProductPrefill product;
}

/// Core knows no product with [barcode].
final class NotFound extends ProductFinderState {
  const NotFound(this.barcode);

  final String barcode;
}

/// A call failed: [message] says so, [retry] repeats that call.
final class Failed extends ProductFinderState {
  const Failed(this.message, this.retry);

  final String message;
  final void Function() retry;
}

/// Shown when a failed call carries no German text from core.
const productFinderFallbackError =
    'Das hat gerade nicht geklappt. Versuch es bitte nochmal.';

/// Scan or search a product and look it up. Only the newest call's answer
/// counts; nothing scanned or typed is logged.
class ProductFinderNotifier extends Notifier<ProductFinderState> {
  /// Bumped by every call and by [reset]: older answers are dropped.
  int _call = 0;

  @override
  ProductFinderState build() => const Scanning();

  ProductService get _service => ref.read(productServiceProvider);

  /// Looks [barcode] up when scanning; false (ignored) otherwise, so only
  /// the first detection counts.
  bool onBarcode(String barcode) {
    if (state is! Scanning) return false;
    _lookup(barcode);
    return true;
  }

  /// Searches [query] (trimmed); a blank one does nothing.
  void search(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    _search(q);
  }

  void pick(ProductHit hit) => _lookup(hit.barcode);

  /// Repeats the failed call.
  void retry() {
    final s = state;
    if (s is Failed) s.retry();
  }

  /// Back to scanning; a pending answer is dropped.
  void reset() {
    _call++;
    state = const Scanning();
  }

  Future<void> _lookup(String barcode) => _run(
    const LookingUp(),
    () => _service.lookup(barcode),
    (result) => switch (result) {
      ProductFound(:final product) => Found(product),
      ProductNotFound(:final barcode) => NotFound(barcode),
    },
    () => _lookup(barcode),
  );

  Future<void> _search(String query) => _run(
    const Searching(),
    () => _service.search(query),
    SearchResults.new,
    () => _search(query),
  );

  Future<void> _run<T>(
    ProductFinderState loading,
    Future<T> Function() call,
    ProductFinderState Function(T) done,
    void Function() again,
  ) async {
    final id = ++_call;
    state = loading;
    ProductFinderState next;
    try {
      next = done(await call());
    } on ProductException catch (e) {
      next = Failed(e.message ?? productFinderFallbackError, again);
    }
    if (!ref.mounted || id != _call) return;
    state = next;
  }
}

final productFinderProvider =
    NotifierProvider.autoDispose<ProductFinderNotifier, ProductFinderState>(
      ProductFinderNotifier.new,
    );
