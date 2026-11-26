import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/data_share.dart';
import '../providers/core_providers.dart';
import '../utils/logger.dart';

/// A failed share call. [status] is the HTTP status of an error answer
/// (null: no answer or unreadable); [message] is core's German text for it,
/// when the body had one. Never carries link, code or token.
class ShareException implements Exception {
  const ShareException({this.status, this.message});

  final int? status;
  final String? message;

  @override
  String toString() => 'ShareException($status)';
}

class ShareService {
  ShareService(this._client);

  final SupabaseClient _client;

  static const _log = AppLogger('ShareService');

  /// Never `select *`: the two hash columns are not readable.
  static const columns =
      'id, display_name, period, share_meals, share_drinks, share_gut, '
      'share_toilet, share_patterns, share_photos, failed_codes, locked_at, '
      'revoked_at, last_opened_at, open_count, expires_at, created_at';

  Future<List<DataShare>> list() async {
    try {
      final rows = await _client
          .from('data_shares')
          .select(columns)
          .order('created_at', ascending: false);
      return rows.map(DataShare.fromJson).toList();
    } catch (e, st) {
      _log.error('list failed', e, st);
      rethrow;
    }
  }

  Future<CreatedShare> create(NewShare share) async {
    final Object? data;
    try {
      final response = await _client.functions.invoke(
        'shares',
        body: {
          'display_name': share.displayName,
          'period': share.period.jsonValue,
          'valid_days': share.validDays,
          'meals': share.meals,
          'drinks': share.drinks,
          'gut': share.gut,
          'toilet': share.toilet,
          'patterns': share.patterns,
          'photos': share.photos,
        },
      );
      data = response.data;
    } on FunctionException catch (e) {
      _log.warn('create failed (${e.status})');
      throw ShareException(status: e.status, message: _messageOf(e));
    } catch (e, st) {
      _log.error('create failed', e, st);
      throw const ShareException();
    }
    try {
      if (data is! Map) throw const FormatException('not a JSON object');
      return CreatedShare(
        id: data['id'] as String,
        link: data['link'] as String,
        code: data['code'] as String,
        expiresAt: DateTime.parse(data['expires_at'] as String),
      );
    } catch (e, st) {
      _log.error('create: unreadable answer', e, st);
      throw const ShareException();
    }
  }

  Future<void> end(String id) async {
    try {
      await _client.functions.invoke('shares/$id/end');
    } on FunctionException catch (e) {
      _log.warn('end failed (${e.status})');
      throw ShareException(status: e.status, message: _messageOf(e));
    } catch (e, st) {
      _log.error('end failed', e, st);
      throw const ShareException();
    }
  }

  /// The error body's German `message`, falling back to `error`; null when
  /// the body isn't a JSON object (a proxy's text page) or has none.
  static String? _messageOf(FunctionException e) {
    final details = e.details;
    if (details is! Map) return null;
    final text = details['message'] ?? details['error'];
    return text is String && text.isNotEmpty ? text : null;
  }
}

final shareServiceProvider = Provider<ShareService>(
  (ref) => ShareService(ref.watch(supabaseClientProvider)),
);
