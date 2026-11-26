import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/models/data_share.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/services/share_secrets_store.dart';

import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
  });

  ProviderContainer makeContainer() => createContainer(
    overrides: [authRepositoryProvider.overrideWithValue(mockRepo)],
  );

  group('AuthNotifier.signInWithEmail', () {
    test('success → state becomes AsyncData', () async {
      when(
        () => mockRepo.signInWithEmail(any(), any()),
      ).thenAnswer((_) async => AuthResponse());

      final container = makeContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      await notifier.signInWithEmail('test@test.com', 'pass');

      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncData<void>>());
    });

    test('error → state becomes AsyncError and rethrows', () async {
      when(
        () => mockRepo.signInWithEmail(any(), any()),
      ).thenThrow(Exception('login failed'));

      final container = makeContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      await expectLater(
        () => notifier.signInWithEmail('test@test.com', 'wrong'),
        throwsA(isA<Exception>()),
      );

      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncError<void>>());
    });
  });

  group('AuthNotifier.signUpWithEmail', () {
    test('success → state becomes AsyncData', () async {
      when(
        () => mockRepo.signUpWithEmail(any(), any()),
      ).thenAnswer((_) async => AuthResponse());

      final container = makeContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      await notifier.signUpWithEmail('new@test.com', 'secret');

      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncData<void>>());
    });
  });

  group('AuthNotifier.signInWithGoogle', () {
    test('success → state becomes AsyncData', () async {
      when(
        () => mockRepo.signInWithGoogle(),
      ).thenAnswer((_) async => AuthResponse());

      final container = makeContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      await notifier.signInWithGoogle();

      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncData<void>>());
    });
  });

  group('AuthNotifier.signInWithApple', () {
    test('success → state becomes AsyncData', () async {
      when(
        () => mockRepo.signInWithApple(),
      ).thenAnswer((_) async => AuthResponse());

      final container = makeContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      await notifier.signInWithApple();

      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncData<void>>());
    });
  });

  group('AuthNotifier.signOut', () {
    test('success → state becomes AsyncData', () async {
      when(() => mockRepo.signOut()).thenAnswer((_) async {});

      final container = makeContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      await notifier.signOut();

      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncData<void>>());
    });

    test('error → state becomes AsyncError and rethrows', () async {
      when(() => mockRepo.signOut()).thenThrow(Exception('network error'));

      final container = makeContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      await expectLater(() => notifier.signOut(), throwsA(isA<Exception>()));

      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncError<void>>());
    });
  });

  group('AuthNotifier.resetPassword', () {
    test('delegates to repo without changing state', () async {
      when(() => mockRepo.resetPassword(any())).thenAnswer((_) async {});

      final container = makeContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      await notifier.resetPassword('test@test.com');

      verify(() => mockRepo.resetPassword('test@test.com')).called(1);
      // State should remain unchanged (no loading/data transition)
      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncData<void>>());
    });
  });

  group('AuthNotifier.updatePassword', () {
    test('delegates to repo', () async {
      final userJson = {
        'id': 'user-1',
        'aud': 'authenticated',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-01-01T00:00:00Z',
        'is_anonymous': false,
      };
      when(
        () => mockRepo.updatePassword(any()),
      ).thenAnswer((_) async => UserResponse.fromJson(userJson));

      final container = makeContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      await notifier.updatePassword('newpass123');

      verify(() => mockRepo.updatePassword('newpass123')).called(1);
    });
  });

  group('AuthNotifier.deleteAccount', () {
    test('success → state becomes AsyncData', () async {
      when(() => mockRepo.deleteAccount()).thenAnswer((_) async {});

      final container = makeContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      await notifier.deleteAccount();

      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncData<void>>());
    });
  });

  group('AuthNotifier.detectAuthMethod', () {
    test('returns value from repo', () {
      when(() => mockRepo.detectAuthMethod()).thenReturn('google');

      final container = makeContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      final result = notifier.detectAuthMethod();

      expect(result, equals('google'));
      verify(() => mockRepo.detectAuthMethod()).called(1);
    });

    test('returns null when repo returns null', () {
      when(() => mockRepo.detectAuthMethod()).thenReturn(null);

      final container = makeContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      final result = notifier.detectAuthMethod();

      expect(result, isNull);
    });
  });

  group('share secrets', () {
    const secret = ShareSecret(link: 'l', code: '123456');

    Future<ProviderContainer> containerWithSecret([
      ShareSecretsStore? override,
    ]) async {
      SharedPreferences.setMockInitialValues({});
      final store = ShareSecretsStore(userId: () => 'u1');
      await store.save('s1', secret);
      return createContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockRepo),
          currentUserIdProvider.overrideWithValue('u1'),
          shareSecretsStoreProvider.overrideWithValue(override ?? store),
        ],
      );
    }

    Future<bool> kept(ProviderContainer c) async =>
        await ShareSecretsStore(userId: () => 'u1').read('s1') != null;

    test('are cleared after a successful sign-out', () async {
      when(() => mockRepo.signOut()).thenAnswer((_) async {});
      final container = await containerWithSecret();
      await container.read(authNotifierProvider.notifier).signOut();
      expect(await kept(container), isFalse);
    });

    test('are cleared after a successful account deletion', () async {
      when(() => mockRepo.deleteAccount()).thenAnswer((_) async {});
      final container = await containerWithSecret();
      await container.read(authNotifierProvider.notifier).deleteAccount();
      expect(await kept(container), isFalse);
    });

    test('survive a failed sign-out', () async {
      when(() => mockRepo.signOut()).thenThrow(Exception('offline'));
      final container = await containerWithSecret();
      await expectLater(
        container.read(authNotifierProvider.notifier).signOut(),
        throwsA(isA<Exception>()),
      );
      expect(await kept(container), isTrue);
    });

    test('survive a failed account deletion', () async {
      when(() => mockRepo.deleteAccount()).thenThrow(Exception('offline'));
      final container = await containerWithSecret();
      await expectLater(
        container.read(authNotifierProvider.notifier).deleteAccount(),
        throwsA(isA<Exception>()),
      );
      expect(await kept(container), isTrue);
    });

    test('a failing clear does not fail a successful sign-out', () async {
      when(() => mockRepo.signOut()).thenAnswer((_) async {});
      final container = await containerWithSecret(_FailingStore());
      await container.read(authNotifierProvider.notifier).signOut();
      expect(container.read(authNotifierProvider), isA<AsyncData<void>>());
    });
  });
}

class _FailingStore extends ShareSecretsStore {
  _FailingStore() : super(userId: () => 'u1');

  @override
  Future<void> clearFor(String userId) async => throw Exception('disk');
}
