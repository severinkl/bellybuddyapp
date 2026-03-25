import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AuthRepository {
  final AuthService _authService;
  AuthRepository(this._authService);

  Stream<AuthState> get onAuthStateChange => _authService.onAuthStateChange;

  Future<AuthResponse> signInWithEmail(String email, String password) =>
      _authService.signInWithEmail(email, password);

  Future<AuthResponse> signUpWithEmail(String email, String password) =>
      _authService.signUpWithEmail(email, password);

  Future<AuthResponse> signInWithGoogle() => _authService.signInWithGoogle();
  Future<AuthResponse> signInWithApple() => _authService.signInWithApple();
  Future<void> signOut() => _authService.signOut();
  Future<void> resetPassword(String email) => _authService.resetPassword(email);
  Future<UserResponse> updatePassword(String newPassword) =>
      _authService.updatePassword(newPassword);
  Future<void> deleteAccount() => _authService.deleteAccount();
  String? detectAuthMethod() => _authService.detectAuthMethod();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(authServiceProvider)),
);
