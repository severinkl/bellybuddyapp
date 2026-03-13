import 'package:flutter/foundation.dart';

/// Lightweight structured logger that only outputs in debug mode.
/// Wraps debugPrint with a tag prefix for consistent, filterable log output.
class AppLogger {
  final String _tag;

  const AppLogger(this._tag);

  void debug(String message) {
    if (kDebugMode) debugPrint('$_tag: $message');
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('$_tag [ERROR]: $message');
      if (error != null) debugPrint('$_tag [ERROR]: $error');
      if (stackTrace != null) debugPrint('$_tag [ERROR]: $stackTrace');
    }
  }
}
