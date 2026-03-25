import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';

/// Stream of auth state changes
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// Current user (nullable) — reactive via authStateProvider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(data: (state) => state.session?.user) ??
      Supabase.instance.client.auth.currentUser;
});

/// Whether user is authenticated — reactive
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (state) => state.session != null,
    loading: () => Supabase.instance.client.auth.currentUser != null,
    error: (_, stackTrace) => false,
  );
});

/// Centralized auth operations — screens call this instead of AuthService
class AuthNotifier extends Notifier<AsyncValue<void>> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final response = await _repo.signInWithEmail(email, password);
      state = const AsyncValue.data(null);
      return response;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final response = await _repo.signUpWithEmail(email, password);
      state = const AsyncValue.data(null);
      return response;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<AuthResponse> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final response = await _repo.signInWithGoogle();
      state = const AsyncValue.data(null);
      return response;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<AuthResponse> signInWithApple() async {
    state = const AsyncValue.loading();
    try {
      final response = await _repo.signInWithApple();
      state = const AsyncValue.data(null);
      return response;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _repo.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) => _repo.resetPassword(email);

  Future<UserResponse> updatePassword(String newPassword) =>
      _repo.updatePassword(newPassword);

  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteAccount();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  String? detectAuthMethod() => _repo.detectAuthMethod();
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AsyncValue<void>>(
  AuthNotifier.new,
);
