import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pattern_stats.dart';
import '../utils/function_exception_utils.dart';
import 'edge_function_service.dart';

/// Core answered 402 `plus_required`: Muster is paid, so this is a locked
/// state, not a failure.
class PatternStatsLockedException implements Exception {
  const PatternStatsLockedException();

  @override
  String toString() => 'PatternStatsLockedException';
}

class PatternStatsService {
  PatternStatsService(this._functions);

  final EdgeFunctionService _functions;

  /// Throws [PatternStatsLockedException] on 402 `plus_required`; any
  /// other failure (offline, 403, unreadable answer) is rethrown as is.
  Future<PatternStats> fetch() async {
    try {
      return PatternStats.fromJson(await _functions.invoke('pattern-stats'));
    } on FunctionException catch (e) {
      if (e.status == 402 && e.errorCode == 'plus_required') {
        throw const PatternStatsLockedException();
      }
      rethrow;
    }
  }
}

final patternStatsServiceProvider = Provider<PatternStatsService>(
  (ref) => PatternStatsService(ref.watch(edgeFunctionServiceProvider)),
);
