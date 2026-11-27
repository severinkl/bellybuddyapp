import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/feedback.dart';
import '../providers/core_providers.dart';
import '../utils/function_exception_utils.dart';
import '../utils/logger.dart';

/// A failed feedback call. [status] is the HTTP status of an error answer
/// (null: no answer); [message] is core's German text for it, when it had
/// one. Never carries the feedback text, category or address.
class FeedbackException implements Exception {
  const FeedbackException({this.status, this.message});

  final int? status;
  final String? message;

  @override
  String toString() => 'FeedbackException($status)';
}

class FeedbackService {
  FeedbackService(this._client);

  final SupabaseClient _client;

  static const _log = AppLogger('FeedbackService');

  Future<void> send({
    required FeedbackCategory category,
    required String message,
    required bool replyWanted,
    required FeedbackContext context,
  }) async {
    try {
      await _client.functions.invoke(
        'feedback',
        body: {
          'category': category.jsonValue,
          'message': message,
          'reply_wanted': replyWanted,
          'app_version': context.appVersion,
          'platform': context.platform,
          'os_version': context.osVersion,
        },
      );
      _log.debug('sent (200)');
    } on FunctionException catch (e) {
      _log.warn('failed (${e.status})');
      throw FeedbackException(status: e.status, message: e.errorMessage());
    } catch (_) {
      // Only the outcome: the error object could echo the request.
      _log.warn('failed (no answer)');
      throw const FeedbackException();
    }
  }
}

final feedbackServiceProvider = Provider<FeedbackService>(
  (ref) => FeedbackService(ref.watch(supabaseClientProvider)),
);
