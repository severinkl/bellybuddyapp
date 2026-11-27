import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

import 'helpers/ambient_animations.dart';

/// Every test runs with the ambient animations held still (see
/// [disableAmbientAnimationsForTests]) and the German date formats loaded.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  disableAmbientAnimationsForTests();
  await initializeDateFormatting('de_DE');
  await testMain();
}
