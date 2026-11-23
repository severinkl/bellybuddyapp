import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [error] with the value of [previous] kept, if it had one: a failed
/// refresh keeps showing what was loaded (`value`, `hasValue`) while
/// `hasError` says it failed. Without a previous value, a plain
/// [AsyncError].
///
/// Riverpod 3 offers no public way to build this; `copyWithPrevious` is
/// what its own AsyncNotifier does on a failed rebuild. The tests that
/// pin the kept value catch it if an upgrade changes that.
AsyncValue<T> errorKeepingValue<T>(
  Object error,
  StackTrace stackTrace,
  AsyncValue<T> previous,
) =>
    // ignore: invalid_use_of_internal_member
    AsyncError<T>(error, stackTrace).copyWithPrevious(previous);
