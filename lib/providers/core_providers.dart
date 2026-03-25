import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Core Supabase client — single source for all services
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Current authenticated user's ID (nullable).
/// For auth-reactive providers (currentUserProvider, isAuthenticatedProvider),
/// see auth_provider.dart — those watch the auth state stream.
final currentUserIdProvider = Provider<String?>(
  (ref) => Supabase.instance.client.auth.currentUser?.id,
);
