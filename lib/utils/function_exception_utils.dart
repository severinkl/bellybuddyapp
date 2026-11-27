import 'package:supabase_flutter/supabase_flutter.dart';

extension FunctionExceptionCode on FunctionException {
  /// The error body's machine `code`; null when the body isn't a JSON object
  /// (a proxy's text page), has none, or it isn't a string.
  String? get errorCode => switch (details) {
    {'code': final String code} => code,
    _ => null,
  };
}
