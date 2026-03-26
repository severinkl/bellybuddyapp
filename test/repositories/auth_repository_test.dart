import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/repositories/auth_repository.dart';

import '../helpers/mocks.dart';

void main() {
  late MockAuthService authService;
  late AuthRepository repo;

  setUp(() {
    authService = MockAuthService();
    repo = AuthRepository(authService);
  });

  group('signInWithEmail', () {
    test('delegates to authService.signInWithEmail', () async {
      final response = AuthResponse();
      when(
        () => authService.signInWithEmail(any(), any()),
      ).thenAnswer((_) async => response);

      final result = await repo.signInWithEmail('user@example.com', 'pass123');

      expect(result, equals(response));
      verify(
        () => authService.signInWithEmail('user@example.com', 'pass123'),
      ).called(1);
    });
  });

  group('signUpWithEmail', () {
    test('delegates to authService.signUpWithEmail', () async {
      final response = AuthResponse();
      when(
        () => authService.signUpWithEmail(any(), any()),
      ).thenAnswer((_) async => response);

      final result = await repo.signUpWithEmail('new@example.com', 'secret');

      expect(result, equals(response));
      verify(
        () => authService.signUpWithEmail('new@example.com', 'secret'),
      ).called(1);
    });
  });

  group('signOut', () {
    test('delegates to authService.signOut', () async {
      when(() => authService.signOut()).thenAnswer((_) async {});

      await repo.signOut();

      verify(() => authService.signOut()).called(1);
    });
  });

  group('resetPassword', () {
    test('delegates to authService.resetPassword', () async {
      when(() => authService.resetPassword(any())).thenAnswer((_) async {});

      await repo.resetPassword('user@example.com');

      verify(() => authService.resetPassword('user@example.com')).called(1);
    });
  });

  group('detectAuthMethod', () {
    test('delegates to authService.detectAuthMethod and returns result', () {
      when(() => authService.detectAuthMethod()).thenReturn('google');

      final result = repo.detectAuthMethod();

      expect(result, equals('google'));
      verify(() => authService.detectAuthMethod()).called(1);
    });

    test('returns null when authService returns null', () {
      when(() => authService.detectAuthMethod()).thenReturn(null);

      final result = repo.detectAuthMethod();

      expect(result, isNull);
    });
  });
}
