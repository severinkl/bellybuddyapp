import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The value an [AsyncValue] settled on.
extension SettledValue<T> on AsyncValue<T> {
  /// The loaded value, once nothing is loading: null while it loads, while
  /// it refreshes or rebuilds (the previous value it still holds may be
  /// another user's) and after an error.
  T? get settledValue => switch (this) {
    AsyncData(:final value, isLoading: false) => value,
    _ => null,
  };

  /// The value to show now: null while it refreshes, rebuilds or after an
  /// error, else [value]. Unlike [settledValue] it keeps the previous value
  /// while a refetch of the same user loads (an [AsyncData] with
  /// [isLoading]), and drops it when it may be another user's (reloading
  /// after a rebuild) or the load failed.
  T? get currentValue => isReloading || hasError ? null : value;
}
