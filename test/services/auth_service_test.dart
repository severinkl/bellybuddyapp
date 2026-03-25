import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/services/auth_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';

class _FakeUserAttributes extends Fake implements UserAttributes {}

/// Helper: create a minimal [User] with the given [appMetadata].
User _makeUser(Map<String, dynamic> appMetadata) => User(
  id: testUserId,
  appMetadata: appMetadata,
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

/// Helper: create a minimal [Session] with the given [appMetadata].
Session _makeSession(Map<String, dynamic> appMetadata) => Session(
  accessToken: 'access-token',
  tokenType: 'bearer',
  user: _makeUser(appMetadata),
);

void main() {
  late MockGoTrueClient auth;
  late MockEdgeFunctionService edgeFunctions;
  late AuthService service;

  setUp(() {
    auth = MockGoTrueClient();
    edgeFunctions = MockEdgeFunctionService();
    service = AuthService(auth, edgeFunctions);
  });

  // Register fallback values for named-argument matchers.
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(_FakeUserAttributes());
  });

  group('AuthService.signInWithEmail', () {
    test(
      'delegates to _auth.signInWithPassword and returns response',
      () async {
        final user = _makeUser({'provider': 'email'});
        final response = AuthResponse(user: user);
        when(
          () => auth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => response);

        final result = await service.signInWithEmail('a@b.com', 'secret');

        expect(result.user?.id, testUserId);
        verify(
          () => auth.signInWithPassword(email: 'a@b.com', password: 'secret'),
        ).called(1);
      },
    );

    test('propagates error from _auth.signInWithPassword', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const AuthException('invalid credentials'));

      await expectLater(
        service.signInWithEmail('a@b.com', 'wrong'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('AuthService.signUpWithEmail', () {
    test(
      'delegates to _auth.signUp and fires welcome email when user exists',
      () async {
        final user = _makeUser({'provider': 'email'});
        final response = AuthResponse(user: user);
        when(
          () => auth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => response);
        when(
          () => edgeFunctions.invoke(any(), body: any(named: 'body')),
        ).thenAnswer((_) async => {});

        final result = await service.signUpWithEmail('new@user.com', 'pass123');

        expect(result.user?.id, testUserId);
        verify(
          () => auth.signUp(email: 'new@user.com', password: 'pass123'),
        ).called(1);
        // Give the fire-and-forget a chance to execute before verifying.
        await Future<void>.delayed(Duration.zero);
        verify(
          () => edgeFunctions.invoke(
            'send-welcome-email',
            body: {'email': 'new@user.com'},
          ),
        ).called(1);
      },
    );

    test('skips welcome email when response.user is null', () async {
      // AuthResponse with no user (e.g. email confirmation pending).
      final response = AuthResponse();
      when(
        () => auth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => response);

      await service.signUpWithEmail('pending@user.com', 'pass123');

      await Future<void>.delayed(Duration.zero);
      verifyNever(() => edgeFunctions.invoke(any(), body: any(named: 'body')));
    });
  });

  group('AuthService.signOut', () {
    test('delegates to _auth.signOut', () async {
      when(() => auth.signOut()).thenAnswer((_) async {});

      await service.signOut();

      verify(() => auth.signOut()).called(1);
    });
  });

  group('AuthService.resetPassword', () {
    test('calls edge function send-password-reset with email', () async {
      when(
        () => edgeFunctions.invoke(any(), body: any(named: 'body')),
      ).thenAnswer((_) async => {});

      await service.resetPassword('user@example.com');

      verify(
        () => edgeFunctions.invoke(
          'send-password-reset',
          body: {'email': 'user@example.com'},
        ),
      ).called(1);
    });
  });

  group('AuthService.updatePassword', () {
    test('delegates to _auth.updateUser with UserAttributes', () async {
      final userResponse = UserResponse.fromJson({
        'id': testUserId,
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'aud': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z',
      });
      when(() => auth.updateUser(any())).thenAnswer((_) async => userResponse);

      await service.updatePassword('newPass99');

      final captured = verify(() => auth.updateUser(captureAny())).captured;
      final attrs = captured.first as UserAttributes;
      expect(attrs.password, 'newPass99');
    });
  });

  group('AuthService.deleteAccount', () {
    test('calls delete-account edge function then signs out', () async {
      when(
        () => edgeFunctions.invoke(any(), body: any(named: 'body')),
      ).thenAnswer((_) async => {});
      when(() => edgeFunctions.invoke(any())).thenAnswer((_) async => {});
      when(() => auth.signOut()).thenAnswer((_) async {});

      await service.deleteAccount();

      verify(() => edgeFunctions.invoke('delete-account')).called(1);
      verify(() => auth.signOut()).called(1);
    });
  });

  group('AuthService.detectAuthMethod', () {
    test('returns google when provider is google', () {
      when(
        () => auth.currentSession,
      ).thenReturn(_makeSession({'provider': 'google'}));

      expect(service.detectAuthMethod(), 'google');
    });

    test('returns apple when provider is apple', () {
      when(
        () => auth.currentSession,
      ).thenReturn(_makeSession({'provider': 'apple'}));

      expect(service.detectAuthMethod(), 'apple');
    });

    test('returns email when provider is email', () {
      when(
        () => auth.currentSession,
      ).thenReturn(_makeSession({'provider': 'email'}));

      expect(service.detectAuthMethod(), 'email');
    });

    test('returns null when currentSession is null', () {
      when(() => auth.currentSession).thenReturn(null);

      expect(service.detectAuthMethod(), isNull);
    });
  });
}
