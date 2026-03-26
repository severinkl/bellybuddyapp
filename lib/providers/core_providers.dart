import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Re-export currentUserIdProvider so existing imports from core_providers
// continue to work. The provider is defined in auth_provider.dart where
// it can reactively derive from currentUserProvider.
export 'auth_provider.dart' show currentUserIdProvider;

/// Core Supabase client — single source for all services
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
