import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import '../providers/core_providers.dart';
import '../utils/function_exception_utils.dart';
import '../utils/logger.dart';

/// A failed product call. [status] is the HTTP status of an error answer
/// (null: no answer or unreadable); [message] is core's German text for it,
/// when the body had one. Never carries barcode or query.
class ProductException implements Exception {
  const ProductException({this.status, this.message});

  final int? status;
  final String? message;

  @override
  String toString() => 'ProductException($status)';
}

class ProductService {
  ProductService(this._client);

  final SupabaseClient _client;

  static const _log = AppLogger('ProductService');

  Future<ProductLookup> lookup(String barcode) async {
    final data = await _invoke('lookup', {'barcode': barcode});
    return _parse('lookup', data, (map) {
      if (map['found'] == true) {
        final p = map['product'];
        if (p is! Map) throw const FormatException('no product');
        return ProductFound(
          ProductPrefill(
            barcode: p['barcode'] as String,
            title: p['name'] as String,
            brand: p['brand'] as String?,
            ingredients: [
              for (final i in p['ingredients'] as List)
                ProductIngredient(
                  name: (i as Map)['name'] as String,
                  ingredientId: i['ingredientId'] as String?,
                ),
            ],
          ),
        );
      }
      if (map['found'] == false) {
        return ProductNotFound(map['barcode'] as String);
      }
      throw const FormatException('unknown answer');
    });
  }

  Future<List<ProductHit>> search(String query) async {
    final data = await _invoke('search', {'q': query});
    return _parse('search', data, (map) {
      return [
        for (final h in map['results'] as List)
          ProductHit(
            barcode: (h as Map)['barcode'] as String,
            name: h['name'] as String,
            brand: h['brand'] as String?,
          ),
      ];
    });
  }

  /// Reads [data] with [read]; anything but a JSON object, or a shape
  /// [read] rejects, is a [ProductException] (logged for [op], never the
  /// data).
  T _parse<T>(String op, Object? data, T Function(Map<String, dynamic>) read) {
    try {
      if (data is! Map) throw const FormatException('not a JSON object');
      return read(Map<String, dynamic>.from(data));
    } catch (e, st) {
      _log.error('$op: unreadable answer', e, st);
      throw const ProductException();
    }
  }

  Future<Object?> _invoke(String op, Map<String, Object?> body) async {
    try {
      final response = await _client.functions.invoke(
        'product-lookup',
        body: body,
      );
      return response.data;
    } on FunctionException catch (e) {
      _log.warn('$op failed (${e.status})');
      throw ProductException(status: e.status, message: e.errorMessage());
    } catch (e, st) {
      _log.error('$op failed', e, st);
      throw const ProductException();
    }
  }
}

final productServiceProvider = Provider<ProductService>(
  (ref) => ProductService(ref.watch(supabaseClientProvider)),
);
