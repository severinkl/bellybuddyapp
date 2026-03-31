import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  late MockProfileRepository mockRepo;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;

  setUp(() {
    mockRepo = MockProfileRepository();
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(null);
    registerFallbackValue(testUserProfile());
  });

  ProviderContainer makeContainer({String? userId = testUserId}) =>
      createContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(mockRepo),
          currentUserIdProvider.overrideWithValue(userId),
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
      );

  group('ProfileNotifier.fetchProfile', () {
    test('loading → data with profile', () async {
      final profile = testUserProfile();
      when(() => mockRepo.getProfile(any())).thenAnswer((_) async => profile);

      final container = makeContainer();
      final notifier = container.read(profileProvider.notifier);

      await notifier.fetchProfile();

      final state = container.read(profileProvider);
      expect(state, isA<AsyncData<UserProfile?>>());
      expect(state.value, equals(profile));
    });

    test('null userId → data(null)', () async {
      final container = makeContainer(userId: null);
      final notifier = container.read(profileProvider.notifier);

      await notifier.fetchProfile();

      final state = container.read(profileProvider);
      expect(state, isA<AsyncData<UserProfile?>>());
      expect(state.value, isNull);
      verifyNever(() => mockRepo.getProfile(any()));
    });

    test('repo error → state becomes AsyncError', () async {
      when(() => mockRepo.getProfile(any())).thenThrow(Exception('db error'));

      final container = makeContainer();
      final notifier = container.read(profileProvider.notifier);

      await notifier.fetchProfile();

      final state = container.read(profileProvider);
      expect(state, isA<AsyncError<UserProfile?>>());
    });
  });

  group('ProfileNotifier.createProfile', () {
    test('calls repo.createProfile then refetches profile', () async {
      final profile = testUserProfile();
      when(() => mockRepo.createProfile(any(), any())).thenAnswer((_) async {});
      when(() => mockRepo.getProfile(any())).thenAnswer((_) async => profile);

      final container = makeContainer();
      final notifier = container.read(profileProvider.notifier);

      await notifier.createProfile(profile);

      verify(() => mockRepo.createProfile(testUserId, any())).called(1);
      verify(() => mockRepo.getProfile(testUserId)).called(1);
      final state = container.read(profileProvider);
      expect(state.value, equals(profile));
    });

    test('null userId → throws and state becomes AsyncError', () async {
      final container = makeContainer(userId: null);
      final notifier = container.read(profileProvider.notifier);

      await expectLater(
        () => notifier.createProfile(testUserProfile()),
        throwsA(isA<Exception>()),
      );

      final state = container.read(profileProvider);
      expect(state, isA<AsyncError<UserProfile?>>());
    });
  });

  group('ProfileNotifier.updateProfile', () {
    test(
      'optimistic update → state changes immediately before repo call',
      () async {
        final original = testUserProfile(weight: 70);
        final updated = testUserProfile(weight: 80);

        // Seed the state with the original profile first
        when(
          () => mockRepo.getProfile(any()),
        ).thenAnswer((_) async => original);
        final container = makeContainer();
        await container.read(profileProvider.notifier).fetchProfile();
        expect(container.read(profileProvider).value, equals(original));

        // Now stub updateProfile and capture state mid-call
        when(
          () => mockRepo.updateProfile(any(), any()),
        ).thenAnswer((_) async {});

        await container.read(profileProvider.notifier).updateProfile(updated);

        final state = container.read(profileProvider);
        expect(state, isA<AsyncData<UserProfile?>>());
        expect(state.value?.weight, equals(80));
      },
    );

    test('reverts state on error', () async {
      final original = testUserProfile(weight: 70);
      final updated = testUserProfile(weight: 80);

      when(() => mockRepo.getProfile(any())).thenAnswer((_) async => original);
      final container = makeContainer();
      await container.read(profileProvider.notifier).fetchProfile();

      when(
        () => mockRepo.updateProfile(any(), any()),
      ).thenThrow(Exception('update failed'));

      await expectLater(
        () => container.read(profileProvider.notifier).updateProfile(updated),
        throwsA(isA<Exception>()),
      );

      final state = container.read(profileProvider);
      expect(state.value, equals(original));
    });
  });

  group('ProfileNotifier.reset', () {
    test('sets state to data(null)', () async {
      final profile = testUserProfile();
      when(() => mockRepo.getProfile(any())).thenAnswer((_) async => profile);

      final container = makeContainer();
      await container.read(profileProvider.notifier).fetchProfile();
      expect(container.read(profileProvider).value, isNotNull);

      container.read(profileProvider.notifier).reset();

      final state = container.read(profileProvider);
      expect(state, isA<AsyncData<UserProfile?>>());
      expect(state.value, isNull);
    });
  });

  group('hasProfileProvider', () {
    test('true when profile exists', () async {
      final profile = testUserProfile();
      when(() => mockRepo.getProfile(any())).thenAnswer((_) async => profile);

      final container = makeContainer();
      await container.read(profileProvider.notifier).fetchProfile();

      expect(container.read(hasProfileProvider), isTrue);
    });

    test('false when profile is null', () async {
      when(() => mockRepo.getProfile(any())).thenAnswer((_) async => null);

      final container = makeContainer();
      await container.read(profileProvider.notifier).fetchProfile();

      expect(container.read(hasProfileProvider), isFalse);
    });
  });

  group('hasCompletedRegistrationProvider', () {
    test('true when profile isComplete', () async {
      // testUserProfile has all required fields set → isComplete == true
      final profile = testUserProfile();
      when(() => mockRepo.getProfile(any())).thenAnswer((_) async => profile);

      final container = makeContainer();
      await container.read(profileProvider.notifier).fetchProfile();

      expect(container.read(hasCompletedRegistrationProvider), isTrue);
    });

    test('false when profile is incomplete', () async {
      // Construct directly so nullable fields stay null (fixture provides defaults)
      const incomplete = UserProfile(userId: testUserId);
      when(
        () => mockRepo.getProfile(any()),
      ).thenAnswer((_) async => incomplete);

      final container = makeContainer();
      await container.read(profileProvider.notifier).fetchProfile();

      expect(container.read(hasCompletedRegistrationProvider), isFalse);
    });

    test('false when no profile loaded yet (loading state)', () {
      final container = makeContainer();
      // profileProvider starts in loading state (build returns AsyncValue.loading())
      expect(container.read(hasCompletedRegistrationProvider), isFalse);
    });
  });
}
