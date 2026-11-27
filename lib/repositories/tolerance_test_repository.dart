import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tolerance_test.dart';
import '../providers/core_providers.dart';
import '../utils/date_format_utils.dart';
import '../utils/logger.dart';

/// Another test is active: the one-active-test index (Postgres `23505`)
/// rejected the insert.
class TestConflict implements Exception {
  const TestConflict();

  @override
  String toString() => 'TestConflict';
}

/// An update to end a test changed no row: it is no longer active (or
/// not visible to the user), so nothing was stored.
class TestNotEnded implements Exception {
  const TestNotEnded();

  @override
  String toString() => 'TestNotEnded';
}

/// The user's `tolerance_tests` rows through PostgREST (RLS, column grants):
/// insert the subject, origin and `starts_on` (the lengths take the server
/// defaults); update only `status` and `ended_at`, only while active.
class ToleranceTestRepository {
  ToleranceTestRepository(
    this._client,
    this._userId, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SupabaseClient _client;
  final String? Function() _userId;
  final DateTime Function() _now;

  static const _log = AppLogger('ToleranceTestRepository');
  static const _table = 'tolerance_tests';
  static const _pgUniqueViolation = '23505';

  /// Starts a test of [s] on [startsOn]. Throws [TestConflict] while
  /// another test is active, [StateError] while signed out.
  Future<void> start(
    TestSubject s, {
    required String origin,
    required DateTime startsOn,
  }) async {
    final userId = _userId();
    if (userId == null) throw StateError('not signed in');
    try {
      await _client.from(_table).insert({
        'user_id': userId,
        'subject_kind': s.kind,
        'subject_key': s.key,
        'subject_name': s.name,
        'origin': origin,
        'starts_on': formatIsoDate(startsOn),
      });
    } on PostgrestException catch (e) {
      if (e.code == _pgUniqueViolation) throw const TestConflict();
      // Only the code: a check violation's details carry the row, with
      // the subject's name.
      _log.error('start failed (${e.code})');
      rethrow;
    } catch (e, st) {
      _log.error('start failed', e, st);
      rethrow;
    }
  }

  /// Stops the test. Throws [TestNotEnded] when no row changed (no longer
  /// active).
  Future<void> stop(String id) => _end(id, 'stopped');

  /// Completes the test. Throws [TestNotEnded] when no row changed (no
  /// longer active).
  Future<void> complete(String id) => _end(id, 'completed');

  Future<void> _end(String id, String status) async {
    final List<Map<String, dynamic>> rows;
    try {
      rows = await _client
          .from(_table)
          .update({
            'status': status,
            // A real instant, never the wall clock.
            'ended_at': _now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('status', 'active')
          .select('id');
    } on PostgrestException catch (e) {
      _log.error('setting $status failed (${e.code})');
      rethrow;
    } catch (e, st) {
      _log.error('setting $status failed', e, st);
      rethrow;
    }
    if (rows.isEmpty) {
      _log.error('setting $status changed no row');
      throw const TestNotEnded();
    }
  }
}

final toleranceTestRepositoryProvider = Provider<ToleranceTestRepository>(
  (ref) => ToleranceTestRepository(
    ref.watch(supabaseClientProvider),
    () => ref.read(currentUserIdProvider),
  ),
);
