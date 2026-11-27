import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';
import '../services/share_secrets_store.dart';
import '../utils/logger.dart';
import 'plus_provider.dart';

/// Stream of auth state changes
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// Current user (nullable) — reactive via authStateProvider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(data: (state) => state.session?.user) ??
      ref.read(authRepositoryProvider).currentUser;
});

/// Current user ID (nullable) — reactive, derived from currentUserProvider
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.id;
});

extension CurrentUserRef on Ref {
  /// Whether [userId] is still the signed-in user (null: still signed out),
  /// after an await, and the provider still there: what was fetched for a
  /// previous user lands nowhere.
  bool isCurrentUser(String? userId) =>
      mounted && read(currentUserIdProvider) == userId;
}

/// Whether user is authenticated — reactive
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (state) => state.session != null,
    loading: () => ref.read(authRepositoryProvider).isAuthenticated,
    error: (_, stackTrace) => false,
  );
});

/// Centralized auth operations — screens call this instead of AuthService
class AuthNotifier extends Notifier<AsyncValue<void>> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  static const _log = AppLogger('AuthNotifier');

  /// Forgets this device's share links and codes of [userId], after a
  /// sign-out or deletion that succeeded. Best effort: a failure is logged
  /// and never turns the success into a failure.
  Future<void> _clearShareSecrets(String? userId) async {
    if (userId == null) return;
    try {
      await ref.read(shareSecretsStoreProvider).clearFor(userId);
    } catch (e, st) {
      _log.error('clearing share secrets failed', e, st);
    }
  }

  /// Logs the purchases SDK out after a successful deletion (R18). Never
  /// built in this run → the SDK was never configured, nothing to do.
  Future<void> _forgetPurchases() async {
    if (!ref.read(plusProvider.exists)) return;
    await ref.read(plusProvider.notifier).forgetDevice();
  }

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
    final userId = ref.read(currentUserIdProvider);
    try {
      await _repo.signOut();
      await _clearShareSecrets(userId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      // gotrue drops the local session before its server call: signed out
      // on this device although the call failed, the secrets go too.
      if (_repo.currentUser == null) await _clearShareSecrets(userId);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) => _repo.resetPassword(email);

  Future<UserResponse> updatePassword(String newPassword) =>
      _repo.updatePassword(newPassword);

  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    final userId = ref.read(currentUserIdProvider);
    try {
      await _repo.deleteAccount();
      await _clearShareSecrets(userId);
      await _forgetPurchases();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      // gotrue drops the local session before its server call: signed out
      // on this device although the call failed, the secrets go too.
      if (_repo.currentUser == null) await _clearShareSecrets(userId);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  String? detectAuthMethod() => _repo.detectAuthMethod();
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AsyncValue<void>>(
  AuthNotifier.new,
);
