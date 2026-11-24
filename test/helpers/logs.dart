import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the logger prints during the test, line by line, and nothing on the
/// console: `debugPrint` is captured until the test's teardown.
List<String> captureLogs() {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  addTearDown(() => debugPrint = original);
  return logs;
}
