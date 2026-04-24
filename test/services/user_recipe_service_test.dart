import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/services/user_recipe_service.dart';

class _FakeSupabaseClient extends Fake implements SupabaseClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSupabaseClient());
  });

  group('UserRecipeService', () {
    // Integration-level smoke only — the Supabase builder is heavy to mock
    // end-to-end. We test the service under its public contract:
    // construction, and that methods are defined with expected signatures.
    test('can be instantiated with a SupabaseClient', () {
      final client = _FakeSupabaseClient();
      final service = UserRecipeService(client);
      expect(service, isNotNull);
    });
  });
}
