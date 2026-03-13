import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

/// Stream of auth state changes
final authStateProvider = StreamProvider<AuthState>((ref) {
  return AuthService.onAuthStateChange;
});

/// Current user (nullable)
final currentUserProvider = Provider<User?>((ref) {
  return SupabaseService.currentUser;
});

/// Whether user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (state) => state.session != null,
    loading: () => SupabaseService.isAuthenticated,
    error: (_, _) => false,
  );
});
