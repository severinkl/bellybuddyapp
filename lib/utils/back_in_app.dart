import 'dart:async';

import 'package:flutter/gestures.dart'
    show GestureBinding, PointerDownEvent, PointerEvent;
import 'package:flutter/widgets.dart' show AppLifecycleListener;

/// Completes once the user is back in the app after something opened over
/// it (the in-app browser), on the first of:
/// - the app resumed after it was left, also when it was left before this
///   was called ([AppLifecycleListener.onResume]: Android's Custom Tabs, or
///   iOS when the app went to the background meanwhile);
/// - the first touch on the app (iOS's in-app browser leaves the app
///   resumed, and no touch reaches the app while it is shown).
///
/// Never completes while neither happens.
Future<void> backInApp() => _BackInApp().back.future;

/// [backInApp]'s listeners, both gone once it completed.
class _BackInApp {
  _BackInApp() {
    _lifecycle = AppLifecycleListener(onResume: _done);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  final back = Completer<void>();
  late final AppLifecycleListener _lifecycle;

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) _done();
  }

  void _done() {
    if (back.isCompleted) return;
    _lifecycle.dispose();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    back.complete();
  }
}
