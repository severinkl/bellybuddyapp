import 'package:mocktail/mocktail.dart';

import 'mocks.dart';

/// Sets up a mock chain for `client.from(table).select(columns)`.
/// Returns the filter builder for further `.eq()`, `.gte()` etc. chaining.
MockPostgrestFilterBuilder mockSelect(
  MockSupabaseClient client, {
  required String table,
}) {
  final queryBuilder = MockSupabaseQueryBuilder();
  final filterBuilder = MockPostgrestFilterBuilder();
  when(() => client.from(table)).thenReturn(queryBuilder);
  when(() => queryBuilder.select(any())).thenReturn(filterBuilder);
  return filterBuilder;
}

/// Sets up a mock chain for `client.from(table).insert(data)`.
MockPostgrestFilterBuilder mockInsert(
  MockSupabaseClient client, {
  required String table,
}) {
  final queryBuilder = MockSupabaseQueryBuilder();
  final filterBuilder = MockPostgrestFilterBuilder();
  when(() => client.from(table)).thenReturn(queryBuilder);
  when(() => queryBuilder.insert(any())).thenReturn(filterBuilder);
  return filterBuilder;
}

/// Sets up a mock chain for `client.from(table).update(data)`.
MockPostgrestFilterBuilder mockUpdate(
  MockSupabaseClient client, {
  required String table,
}) {
  final queryBuilder = MockSupabaseQueryBuilder();
  final filterBuilder = MockPostgrestFilterBuilder();
  when(() => client.from(table)).thenReturn(queryBuilder);
  when(() => queryBuilder.update(any())).thenReturn(filterBuilder);
  return filterBuilder;
}

/// Sets up a mock chain for `client.from(table).delete()`.
MockPostgrestFilterBuilder mockDelete(
  MockSupabaseClient client, {
  required String table,
}) {
  final queryBuilder = MockSupabaseQueryBuilder();
  final filterBuilder = MockPostgrestFilterBuilder();
  when(() => client.from(table)).thenReturn(queryBuilder);
  when(() => queryBuilder.delete()).thenReturn(filterBuilder);
  return filterBuilder;
}

/// Sets up a mock chain for `client.from(table).upsert(data)`.
MockPostgrestFilterBuilder mockUpsert(
  MockSupabaseClient client, {
  required String table,
}) {
  final queryBuilder = MockSupabaseQueryBuilder();
  final filterBuilder = MockPostgrestFilterBuilder();
  when(() => client.from(table)).thenReturn(queryBuilder);
  when(
    () => queryBuilder.upsert(any(), onConflict: any(named: 'onConflict')),
  ).thenReturn(filterBuilder);
  return filterBuilder;
}

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
