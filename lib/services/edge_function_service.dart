import 'supabase_service.dart';

class EdgeFunctionService {
  static Future<Map<String, dynamic>> invoke(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    final response = await SupabaseService.client.functions.invoke(
      functionName,
      body: body,
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {'data': response.data};
  }
}
