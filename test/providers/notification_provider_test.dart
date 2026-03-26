import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/notification_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  late MockNotificationRepository mockNotificationRepo;
  late MockProfileRepository mockProfileRepo;

  setUp(() {
    mockNotificationRepo = MockNotificationRepository();
    mockProfileRepo = MockProfileRepository();
    registerFallbackValue(testUserProfile());
  });

  ProviderContainer makeContainer({String? userId = testUserId}) =>
      createContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(
            mockNotificationRepo,
          ),
          profileRepositoryProvider.overrideWithValue(mockProfileRepo),
          currentUserIdProvider.overrideWithValue(userId),
        ],
      );

  group('notificationSyncProvider', () {
    test('calls syncNotifications when profile is loaded', () async {
      final profile = testUserProfile();
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => profile);
      when(
        () => mockNotificationRepo.syncNotifications(any()),
      ).thenAnswer((_) async {});

      final container = makeContainer();

      // Load profile so profileProvider transitions to AsyncData(profile)
      await container.read(profileProvider.notifier).fetchProfile();

      // Reading notificationSyncProvider causes it to react to profileProvider
      container.read(notificationSyncProvider);

      // Give the async syncNotifications call time to fire
      await Future<void>.delayed(Duration.zero);

      verify(() => mockNotificationRepo.syncNotifications(profile)).called(1);
    });

    test('does not call syncNotifications when profile is null', () async {
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockNotificationRepo.syncNotifications(any()),
      ).thenAnswer((_) async {});

      final container = makeContainer();

      // Profile resolves to null
      await container.read(profileProvider.notifier).fetchProfile();

      container.read(notificationSyncProvider);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => mockNotificationRepo.syncNotifications(any()));
    });

    test('does not call syncNotifications when profile is still loading', () {
      final container = makeContainer();

      // profileProvider starts in loading state — do NOT call fetchProfile
      container.read(notificationSyncProvider);

      verifyNever(() => mockNotificationRepo.syncNotifications(any()));
    });
  });
}
