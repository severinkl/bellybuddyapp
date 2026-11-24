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
}
