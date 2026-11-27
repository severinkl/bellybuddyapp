import 'package:flutter/foundation.dart';
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

/// The hits of the last search for [query] (maybe none).
final class SearchResults extends ProductFinderState {
  const SearchResults(this.hits, this.query);

  final List<ProductHit> hits;

  /// The trimmed term searched (the sheet puts it back in its field).
  final String query;

  @override
  bool operator ==(Object other) =>
      other is SearchResults &&
      other.query == query &&
      listEquals(other.hits, hits);

  @override
  int get hashCode => Object.hash(query, Object.hashAll(hits));
}

/// A barcode is being looked up; [from] are the hits it was picked from
/// (null: scanned).
final class LookingUp extends ProductFinderState {
  const LookingUp({this.from});

  final SearchResults? from;
}

/// [from]: the hits the product was picked from (null: scanned); [back]
/// returns to them.
final class Found extends ProductFinderState {
  const Found(this.product, {this.from});

  final ProductPrefill product;
  final SearchResults? from;
}

/// Core knows no product with [barcode]. [from] as for [Found].
final class NotFound extends ProductFinderState {
  const NotFound(this.barcode, {this.from});

  final String barcode;
  final SearchResults? from;
}

/// A call failed: [message] says so; [canRetry] when repeating can help
/// (not when core rejected the barcode or the search term); [search] when it was a search (the
/// sheet keeps the search field then). [from] as for [Found].
final class Failed extends ProductFinderState {
  const Failed(
    this.message, {
    required this.canRetry,
    required this.search,
    this.from,
  });

  final String message;
  final bool canRetry;
  final bool search;
  final SearchResults? from;

  @override
  bool operator ==(Object other) =>
      other is Failed &&
      other.message == message &&
      other.canRetry == canRetry &&
      other.search == search &&
      other.from == from;

  @override
  int get hashCode => Object.hash(message, canRetry, search, from);
}

/// What the notifier repeats on [ProductFinderNotifier.retry].
sealed class _Request {
  const _Request();
}

final class _LookupRequest extends _Request {
  const _LookupRequest(this.barcode, this.from);

  final String barcode;
  final SearchResults? from;
}

final class _SearchRequest extends _Request {
  const _SearchRequest(this.query);

  final String query;
}

/// Shown when a failed call carries no German text from core.
const productFinderFallbackError =
    'Das hat gerade nicht geklappt. Versuch es bitte nochmal.';

/// Scan or search a product and look it up. Only the newest call's answer
/// counts; nothing scanned or typed is logged.
class ProductFinderNotifier extends Notifier<ProductFinderState> {
  /// Bumped by every call and by [reset]: older answers are dropped.
  int _call = 0;

  /// The call a failure repeats.
  _Request? _last;

  /// The hits the shown product (or its failure) was picked from.
  SearchResults? get _from => switch (state) {
    LookingUp(:final from) ||
    Found(:final from) ||
    NotFound(:final from) ||
    Failed(:final from) => from,
    _ => null,
  };

  /// The term of the search the shown product came from (the sheet puts it
  /// back in the field); empty when it was scanned.
  String get lastQuery => _from?.query ?? '';

  /// The shown product (or its failure) came from a search hit: [back]
  /// returns to those hits.
  bool get canReturnToSearch => _from != null;

  @override
  ProductFinderState build() => const Scanning();

  ProductService get _service => ref.read(productServiceProvider);

  /// Looks [barcode] up when scanning; false (ignored) otherwise, so only
  /// the first detection counts.
  bool onBarcode(String barcode) {
    if (state is! Scanning) return false;
    _lookup(barcode, null);
    return true;
  }

  /// Searches [query] (trimmed); a blank one does nothing.
  void search(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    _search(q);
  }

  void pick(ProductHit hit) {
    final s = state;
    _lookup(hit.barcode, s is SearchResults ? s : null);
  }

  /// Repeats the failed call. A failed search searches [query] instead
  /// when it is not blank: the field may have been edited since.
  void retry({String? query}) {
    final s = state;
    if (s is! Failed || !s.canRetry) return;
    if (s.search && query != null && query.trim().isNotEmpty) {
      search(query);
      return;
    }
    switch (_last) {
      case _LookupRequest(:final barcode, :final from):
        _lookup(barcode, from);
      case _SearchRequest(:final query):
        _search(query);
      case null:
        break;
    }
  }

  /// Back to scanning; a pending answer is dropped.
  void reset() {
    _call++;
    state = const Scanning();
  }

  /// Back to the hits the product was picked from ([canReturnToSearch]),
  /// else [reset]. A pending answer is dropped.
  void back() {
    final hits = _from;
    if (hits == null) {
      reset();
      return;
    }
    _call++;
    state = hits;
  }

  Future<void> _lookup(String barcode, SearchResults? from) {
    _last = _LookupRequest(barcode, from);
    return _run(
      LookingUp(from: from),
      () => _service.lookup(barcode),
      (result) => switch (result) {
        ProductFound(:final product) => Found(product, from: from),
        ProductNotFound(:final barcode) => NotFound(barcode, from: from),
      },
    );
  }

  Future<void> _search(String query) {
    _last = _SearchRequest(query);
    return _run(
      const Searching(),
      () => _service.search(query),
      (hits) => SearchResults(hits, query),
    );
  }

  Future<void> _run<T>(
    ProductFinderState loading,
    Future<T> Function() call,
    ProductFinderState Function(T) done,
  ) async {
    final id = ++_call;
    state = loading;
    ProductFinderState next;
    try {
      next = done(await call());
    } on ProductException catch (e) {
      next = Failed(
        e.message ?? productFinderFallbackError,
        // 400: core rejected the barcode or the term (too short, too
        // long); the same call fails again.
        canRetry: e.status != 400,
        search: loading is Searching,
        from: switch (loading) {
          LookingUp(:final from) => from,
          _ => null,
        },
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
