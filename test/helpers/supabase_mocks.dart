import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mocks.dart';

/// A [MockPostgrestFilterBuilder] wrapper that properly resolves as a
/// [Future<PostgrestList>] when awaited (or used with [Future.wait]).
///
/// The [then] method is forwarded to a real [Future] so that type-specific
/// invocations from Dart's async machinery always work.
class SettlableFilterBuilder extends MockPostgrestFilterBuilder {
  SettlableFilterBuilder(this._future);

  final Future<PostgrestList> _future;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) {
    return _future.then(onValue, onError: onError);
  }
}

/// A [MockPostgrestMapNullableTransformBuilder] wrapper that properly resolves
/// as a [Future<PostgrestMap?>] when awaited (or used with [Future.wait]).
class SettlableMapNullable extends MockPostgrestMapNullableTransformBuilder {
  SettlableMapNullable(this._future);

  final Future<PostgrestMap?> _future;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestMap? value) onValue, {
    Function? onError,
  }) {
    return _future.then(onValue, onError: onError);
  }
}

/// Sets up a mock chain for `client.from(table).select(columns)`.
/// Returns the filter builder for further `.eq()`, `.gte()` etc. chaining.
/// The returned builder is NOT yet settled (no rows); call [settleFilter] to
/// assign a resolved Future.
MockPostgrestFilterBuilder mockSelect(
  MockSupabaseClient client, {
  required String table,
}) {
  final queryBuilder = MockSupabaseQueryBuilder();
  final filterBuilder = MockPostgrestFilterBuilder();
  when(() => client.from(table)).thenAnswer((_) => queryBuilder);
  when(() => queryBuilder.select(any())).thenAnswer((_) => filterBuilder);
  return filterBuilder;
}

/// Sets up a mock chain for `client.from(table).insert(data)`.
MockPostgrestFilterBuilder mockInsert(
  MockSupabaseClient client, {
  required String table,
}) {
  final queryBuilder = MockSupabaseQueryBuilder();
  final filterBuilder = MockPostgrestFilterBuilder();
  when(() => client.from(table)).thenAnswer((_) => queryBuilder);
  when(() => queryBuilder.insert(any())).thenAnswer((_) => filterBuilder);
  return filterBuilder;
}

/// Sets up a mock chain for `client.from(table).update(data)`.
MockPostgrestFilterBuilder mockUpdate(
  MockSupabaseClient client, {
  required String table,
}) {
  final queryBuilder = MockSupabaseQueryBuilder();
  final filterBuilder = MockPostgrestFilterBuilder();
  when(() => client.from(table)).thenAnswer((_) => queryBuilder);
  when(() => queryBuilder.update(any())).thenAnswer((_) => filterBuilder);
  return filterBuilder;
}

/// Sets up a mock chain for `client.from(table).delete()`.
MockPostgrestFilterBuilder mockDelete(
  MockSupabaseClient client, {
  required String table,
}) {
  final queryBuilder = MockSupabaseQueryBuilder();
  final filterBuilder = MockPostgrestFilterBuilder();
  when(() => client.from(table)).thenAnswer((_) => queryBuilder);
  when(() => queryBuilder.delete()).thenAnswer((_) => filterBuilder);
  return filterBuilder;
}

/// Sets up a mock chain for `client.from(table).upsert(data)`.
MockPostgrestFilterBuilder mockUpsert(
  MockSupabaseClient client, {
  required String table,
}) {
  final queryBuilder = MockSupabaseQueryBuilder();
  final filterBuilder = MockPostgrestFilterBuilder();
  when(() => client.from(table)).thenAnswer((_) => queryBuilder);
  when(
    () => queryBuilder.upsert(any(), onConflict: any(named: 'onConflict')),
  ).thenAnswer((_) => filterBuilder);
  return filterBuilder;
}

/// Sets up a select mock chain that resolves with [rows] when awaited.
///
/// Use this instead of [mockSelect] + manual [then] stubbing in tests that
/// need [Future.wait] to work correctly (e.g. [EntryQueryService]).
SettlableFilterBuilder mockSelectRows(
  MockSupabaseClient client, {
  required String table,
  required List<Map<String, dynamic>> rows,
}) {
  final queryBuilder = MockSupabaseQueryBuilder();
  final filterBuilder = SettlableFilterBuilder(Future.value(rows));
  when(() => client.from(table)).thenAnswer((_) => queryBuilder);
  when(() => queryBuilder.select(any())).thenAnswer((_) => filterBuilder);
  return filterBuilder;
}

/// Creates a settled [MockPostgrestMapNullableTransformBuilder] that resolves
/// with [value] when awaited. Useful for [ProfileService.fetchByUserId].
SettlableMapNullable settleMaybeSingle(PostgrestMap? value) =>
    SettlableMapNullable(Future.value(value));

/// Sets up `client.storage.from(bucket)` chain.
MockStorageFileApi mockStorage(
  MockSupabaseClient client, {
  required String bucket,
}) {
  final storage = MockSupabaseStorageClient();
  final fileApi = MockStorageFileApi();
  when(() => client.storage).thenReturn(storage);
  when(() => storage.from(bucket)).thenReturn(fileApi);
  return fileApi;
}

/// Sets up `client.functions` mock.
MockFunctionsClient mockFunctions(MockSupabaseClient client) {
  final functions = MockFunctionsClient();
  when(() => client.functions).thenReturn(functions);
  return functions;
}
