import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/repositories/profile_repository.dart';

import '../helpers/mocks.dart';
import '../helpers/fixtures.dart';

void main() {
  late MockProfileService profileService;
  late MockAuthService authService;
  late ProfileRepository repo;

  setUpAll(() {
    registerFallbackValue(testUserProfile());
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    profileService = MockProfileService();
    authService = MockAuthService();
    repo = ProfileRepository(profileService, authService);
  });

  group('getProfile', () {
    test(
      'delegates to profileService.fetchByUserId and returns result',
      () async {
        final profile = testUserProfile();
        when(
          () => profileService.fetchByUserId(any()),
        ).thenAnswer((_) async => profile);

        final result = await repo.getProfile('user-123');

        expect(result, equals(profile));
        verify(() => profileService.fetchByUserId('user-123')).called(1);
      },
    );

    test('returns null when service returns null', () async {
      when(
        () => profileService.fetchByUserId(any()),
      ).thenAnswer((_) async => null);

      final result = await repo.getProfile('user-123');

      expect(result, isNull);
    });

    test('propagates exception from service', () async {
      when(
        () => profileService.fetchByUserId(any()),
      ).thenThrow(Exception('network error'));

      expect(() => repo.getProfile('user-123'), throwsException);
    });
  });

  group('createProfile', () {
    test('calls detectAuthMethod and upserts with userId set', () async {
      final profile = testUserProfile(userId: null, authMethod: null);
      when(() => authService.detectAuthMethod()).thenReturn('email');
      when(() => profileService.upsert(any())).thenAnswer((_) async {});

      await repo.createProfile('user-123', profile);

      final captured =
          verify(() => profileService.upsert(captureAny())).captured.single
              as Map<String, dynamic>;

      expect(captured['user_id'], equals('user-123'));
      expect(captured['auth_method'], equals('email'));
      verify(() => authService.detectAuthMethod()).called(1);
    });

    test('strips null values from data before upsert', () async {
      // Profile with many nullable fields set to null
      final profile = testUserProfile(
        userId: null,
        birthYear: null,
        gender: null,
        authMethod: null,
      );
      when(() => authService.detectAuthMethod()).thenReturn('email');
      when(() => profileService.upsert(any())).thenAnswer((_) async {});

      await repo.createProfile('user-123', profile);

      final captured =
          verify(() => profileService.upsert(captureAny())).captured.single
              as Map<String, dynamic>;

      // Null values should have been removed
      for (final entry in captured.entries) {
        expect(
          entry.value,
          isNotNull,
          reason: 'Key "${entry.key}" should not be null',
        );
      }
    });

    test('sets user_id in data map', () async {
      final profile = testUserProfile();
      when(() => authService.detectAuthMethod()).thenReturn('google');
      when(() => profileService.upsert(any())).thenAnswer((_) async {});

      await repo.createProfile('new-user-id', profile);

      final captured =
          verify(() => profileService.upsert(captureAny())).captured.single
              as Map<String, dynamic>;

      expect(captured['user_id'], equals('new-user-id'));
    });

    test('handles null authMethod from detectAuthMethod', () async {
      final profile = testUserProfile(authMethod: null);
      when(() => authService.detectAuthMethod()).thenReturn(null);
      when(() => profileService.upsert(any())).thenAnswer((_) async {});

      await repo.createProfile('user-123', profile);

      final captured =
          verify(() => profileService.upsert(captureAny())).captured.single
              as Map<String, dynamic>;

      // null auth_method should be stripped
      expect(captured.containsKey('auth_method'), isFalse);
    });
  });

  group('updateProfile', () {
    test('delegates to profileService.update without user_id key', () async {
      final profile = testUserProfile(userId: 'user-123');
      when(() => profileService.update(any(), any())).thenAnswer((_) async {});

      await repo.updateProfile('user-123', profile);

      final captured =
          verify(
                () => profileService.update('user-123', captureAny()),
              ).captured.single
              as Map<String, dynamic>;

      expect(captured.containsKey('user_id'), isFalse);
    });

    test('passes userId to profileService.update', () async {
      final profile = testUserProfile();
      when(() => profileService.update(any(), any())).thenAnswer((_) async {});

      await repo.updateProfile('user-abc', profile);

      verify(() => profileService.update('user-abc', any())).called(1);
    });
  });
}
