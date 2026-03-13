import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Whether onboarding has been seen
final isOnboardedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_seen') ?? false;
});

/// Mark onboarding as seen
Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_seen', true);
}
