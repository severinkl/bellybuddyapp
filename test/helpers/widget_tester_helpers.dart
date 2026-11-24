import 'package:flutter_test/flutter_test.dart';

/// Taps that work on a small screen too.
extension TapVisible on WidgetTester {
  /// Scrolls [finder] into view, taps it and lets everything settle.
  Future<void> tapVisible(Finder finder) async {
    await ensureVisible(finder);
    await pumpAndSettle();
    await tap(finder);
    await pumpAndSettle();
  }
}
