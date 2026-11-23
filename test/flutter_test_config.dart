import 'dart:async';

import 'helpers/ambient_animations.dart';

/// Every test runs with the ambient animations held still (see
/// [disableAmbientAnimationsForTests]).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  disableAmbientAnimationsForTests();
  await testMain();
}
