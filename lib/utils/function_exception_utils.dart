import 'package:supabase_flutter/supabase_flutter.dart';

extension FunctionExceptionCode on FunctionException {
  /// The error body's machine `code`; null when the body isn't a JSON object
  /// (a proxy's text page), has none, or it isn't a string.
  String? get errorCode => switch (details) {
    {'code': final String code} => code,
    _ => null,
  };

  /// The error body's German `error` text (with [orMessage], falling back to
  /// `message`); null when the body isn't a JSON object (a proxy's text page),
  /// has none, or it is empty or not a string.
  String? errorMessage({bool orMessage = false}) {
    final body = details;
    if (body is! Map) return null;
    final text = orMessage ? body['error'] ?? body['message'] : body['error'];
    return text is String && text.isNotEmpty ? text : null;
  }
}
