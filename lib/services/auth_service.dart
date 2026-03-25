import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import '../config/oauth_config.dart';
import '../utils/logger.dart';
import 'supabase_service.dart';
import 'edge_function_service.dart';

class AuthService {
  static const _log = AppLogger('AuthService');
  static GoTrueClient get _auth => SupabaseService.auth;

  static Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  static Future<AuthResponse> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithPassword(email: email, password: password);
    } catch (e, st) {
      _log.error('signInWithEmail failed', e, st);
      rethrow;
    }
  }

  static Future<AuthResponse> signUpWithEmail(
    String email,
    String password,
  ) async {
    try {
      final response = await _auth.signUp(email: email, password: password);
      // Fire and forget welcome email
      if (response.user != null) {
        EdgeFunctionService.invoke(
          'send-welcome-email',
          body: {'email': email},
        ).ignore();
      }
      return response;
    } catch (e, st) {
      _log.error('signUpWithEmail failed', e, st);
      rethrow;
    }
  }

  static String _generateNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  static Future<AuthResponse> signInWithGoogle() async {
    const webClientId = OAuthConfig.googleWebClientId;
    const iosClientId = OAuthConfig.googleIosClientId;

    // Generate nonce — pass hashed to Google, raw to Supabase
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    // Must re-initialize each time to set a fresh nonce.
    // clientId is only needed on iOS — on Android, the native client ID
    // comes from google-services.json automatically.
    await GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS ? iosClientId : null,
      serverClientId: webClientId,
      nonce: hashedNonce,
    );

    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;

    if (idToken == null) {
      throw Exception('No ID token received from Google');
    }

    return await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  static Future<AuthResponse> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    return _signInWithIdToken(
      OAuthProvider.apple,
      credential.identityToken,
      'Apple',
    );
  }

  static Future<AuthResponse> _signInWithIdToken(
    OAuthProvider provider,
    String? idToken,
    String providerName,
  ) async {
    if (idToken == null) {
      throw Exception('No ID token received from $providerName');
    }
    return await _auth.signInWithIdToken(provider: provider, idToken: idToken);
  }

  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e, st) {
      _log.error('signOut failed', e, st);
      rethrow;
    }
  }

  static Future<void> resetPassword(String email) async {
    try {
      await EdgeFunctionService.invoke(
        'send-password-reset',
        body: {'email': email},
      );
    } catch (e, st) {
      _log.error('resetPassword failed', e, st);
      rethrow;
    }
  }

  static Future<UserResponse> updatePassword(String newPassword) async {
    try {
      return await _auth.updateUser(UserAttributes(password: newPassword));
    } catch (e, st) {
      _log.error('updatePassword failed', e, st);
      rethrow;
    }
  }

  static Future<void> deleteAccount() async {
    try {
      await EdgeFunctionService.invoke('delete-account');
      await signOut();
    } catch (e, st) {
      _log.error('deleteAccount failed', e, st);
      rethrow;
    }
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
