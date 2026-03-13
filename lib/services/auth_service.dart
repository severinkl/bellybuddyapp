import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import 'supabase_service.dart';
import 'edge_function_service.dart';

class AuthService {
  static GoTrueClient get _auth => SupabaseService.auth;

  static Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  static Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _auth.signInWithPassword(email: email, password: password);
  }

  static Future<AuthResponse> signUpWithEmail(String email, String password) async {
    final response = await _auth.signUp(email: email, password: password);
    // Fire and forget welcome email
    if (response.user != null) {
      EdgeFunctionService.invoke('send-welcome-email', body: {
        'email': email,
      }).ignore();
    }
    return response;
  }

  static bool _googleInitialized = false;

  static Future<AuthResponse> signInWithGoogle() async {
    const webClientId = ''; // TODO: Add Google OAuth web client ID

    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize(serverClientId: webClientId);
      _googleInitialized = true;
    }

    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;

    if (idToken == null) {
      throw Exception('No ID token received from Google');
    }

    return await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  static Future<AuthResponse> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw Exception('No ID token received from Apple');
    }

    return await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
    );
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static Future<void> resetPassword(String email) async {
    await EdgeFunctionService.invoke('send-password-reset', body: {
      'email': email,
    });
  }

  static Future<UserResponse> updatePassword(String newPassword) async {
    return await _auth.updateUser(UserAttributes(password: newPassword));
  }

  static Future<void> deleteAccount() async {
    await EdgeFunctionService.invoke('delete-account');
    await signOut();
  }

  /// Detect auth method from session metadata
  static String? detectAuthMethod() {
    final session = SupabaseService.currentSession;
    if (session == null) return null;

    final provider = session.user.appMetadata['provider'] as String?;
    switch (provider) {
      case 'google':
        return 'google';
      case 'apple':
        return 'apple';
      case 'email':
        return 'email';
      default:
        return 'email';
    }
  }

  static bool get isAppleSignInAvailable => Platform.isIOS;
}
