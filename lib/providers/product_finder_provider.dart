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

/// A call failed: [message] says so, [retry] repeats that call (null when
/// repeating cannot help: core rejected the barcode); [search] when it was
/// a search (the sheet keeps the search field then).
final class Failed extends ProductFinderState {
  const Failed(this.message, this.retry, {this.search = false});

  final String message;
  final void Function()? retry;
  final bool search;
}

/// Shown when a failed call carries no German text from core.
const productFinderFallbackError =
    'Das hat gerade nicht geklappt. Versuch es bitte nochmal.';

/// Scan or search a product and look it up. Only the newest call's answer
/// counts; nothing scanned or typed is logged.
class ProductFinderNotifier extends Notifier<ProductFinderState> {
  /// Bumped by every call and by [reset]: older answers are dropped.
  int _call = 0;

  /// The term of the last search.
  String _lastQuery = '';

  /// The hits the shown product was picked from; null when it was scanned.
  List<ProductHit>? _pickedFrom;

  /// The term of the last search (the sheet puts it back in the field).
  String get lastQuery => _lastQuery;

  /// The shown product (or its failure) came from a search hit: [back]
  /// returns to those hits.
  bool get canReturnToSearch => _pickedFrom != null;

  @override
  ProductFinderState build() => const Scanning();

  ProductService get _service => ref.read(productServiceProvider);

  /// Looks [barcode] up when scanning; false (ignored) otherwise, so only
  /// the first detection counts.
  bool onBarcode(String barcode) {
    if (state is! Scanning) return false;
    _pickedFrom = null;
    _lookup(barcode);
    return true;
  }

  /// Searches [query] (trimmed); a blank one does nothing.
  void search(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    _lastQuery = q;
    _pickedFrom = null;
    _search(q);
  }

  void pick(ProductHit hit) {
    final s = state;
    _pickedFrom = s is SearchResults ? s.hits : null;
    _lookup(hit.barcode);
  }

  /// Repeats the failed call. A failed search searches [query] instead
  /// when it is not blank: the field may have been edited since.
  void retry({String? query}) {
    final s = state;
    if (s is! Failed) return;
    if (s.search && query != null && query.trim().isNotEmpty) {
      search(query);
    } else {
      s.retry?.call();
    }
  }

  /// Back to scanning; a pending answer is dropped.
  void reset() {
    _call++;
    _pickedFrom = null;
    state = const Scanning();
  }

  /// Back to the hits the product was picked from ([canReturnToSearch]),
  /// else [reset]. A pending answer is dropped.
  void back() {
    final hits = _pickedFrom;
    if (hits == null) {
      reset();
      return;
    }
    _call++;
    _pickedFrom = null;
    state = SearchResults(hits);
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
    search: true,
  );

  Future<void> _run<T>(
    ProductFinderState loading,
    Future<T> Function() call,
    ProductFinderState Function(T) done,
    void Function() again, {
    bool search = false,
  }) async {
    final id = ++_call;
    state = loading;
    ProductFinderState next;
    try {
      next = done(await call());
    } on ProductException catch (e) {
      next = Failed(
        e.message ?? productFinderFallbackError,
        // 400: core rejected the barcode; the same lookup fails again.
        !search && e.status == 400 ? null : again,
        search: search,
      );
    }
    if (!ref.mounted || id != _call) return;
    state = next;
  }
}

final productFinderProvider =
    NotifierProvider.autoDispose<ProductFinderNotifier, ProductFinderState>(
      ProductFinderNotifier.new,
    );
