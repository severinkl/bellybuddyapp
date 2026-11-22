import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:belly_buddy/models/buddy_state.dart';
import 'package:belly_buddy/providers/buddy_provider.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/notification_provider.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/repositories/notification_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/riverpod_helpers.dart';

class _FakeBuddy extends BuddyNotifier {
  _FakeBuddy(this.initial);
  final BuddyStatus? initial;

  @override
  Future<BuddyStatus?> build() async => initial;

  void emit(BuddyStatus? status) => state = AsyncData(status);
}

BuddyStatus _status(String name, {bool hasRow = true}) => BuddyStatus(
  state: BuddyState(name: name),
  hasRow: hasRow,
  streak: 0,
  todayCounted: false,
);

void main() {
  late MockNotificationRepository mockNotificationRepo;
  late MockProfileRepository mockProfileRepo;

  setUp(() {
    mockNotificationRepo = MockNotificationRepository();
    mockProfileRepo = MockProfileRepository();
    registerFallbackValue(testUserProfile());
  });

  ProviderContainer makeContainer({
    String? userId = testUserId,
    BuddyStatus? buddy,
    _FakeBuddy? fakeBuddy,
  }) => createContainer(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(mockNotificationRepo),
      profileRepositoryProvider.overrideWithValue(mockProfileRepo),
      currentUserIdProvider.overrideWithValue(userId),
      buddyProvider.overrideWith(() => fakeBuddy ?? _FakeBuddy(buddy)),
    ],
  );

  group('notificationSyncProvider', () {
    test('calls syncNotifications when profile is loaded', () async {
      final profile = testUserProfile();
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => profile);
      when(
        () => mockNotificationRepo.syncNotifications(
          any(),
          buddyName: any(named: 'buddyName'),
        ),
      ).thenAnswer((_) async {});

      final container = makeContainer();

      // Load profile so profileProvider transitions to AsyncData(profile)
      await container.read(profileProvider.notifier).fetchProfile();

      // Reading notificationSyncProvider causes it to react to profileProvider
      container.read(notificationSyncProvider);

      // Give the async syncNotifications call time to fire
      await Future<void>.delayed(Duration.zero);

      verify(
        () => mockNotificationRepo.syncNotifications(profile, buddyName: null),
      ).called(1);
    });

    test('does not call syncNotifications when profile is null', () async {
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockNotificationRepo.syncNotifications(
          any(),
          buddyName: any(named: 'buddyName'),
        ),
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
  test('passes the Buddy name when a row exists', () async {
    final profile = testUserProfile();
    when(
      () => mockProfileRepo.getProfile(any()),
    ).thenAnswer((_) async => profile);
    when(
      () => mockNotificationRepo.syncNotifications(
        any(),
        buddyName: any(named: 'buddyName'),
      ),
    ).thenAnswer((_) async {});

    final container = makeContainer(buddy: _status('Pünktchen'));
    await container.read(buddyProvider.future);
    await container.read(profileProvider.notifier).fetchProfile();
    container.read(notificationSyncProvider);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => mockNotificationRepo.syncNotifications(
        profile,
        buddyName: 'Pünktchen',
      ),
    ).called(1);
  });

  test('omits the name when no Buddy row exists', () async {
    final profile = testUserProfile();
    when(
      () => mockProfileRepo.getProfile(any()),
    ).thenAnswer((_) async => profile);
    when(
      () => mockNotificationRepo.syncNotifications(
        any(),
        buddyName: any(named: 'buddyName'),
      ),
    ).thenAnswer((_) async {});

    final container = makeContainer(buddy: _status('Buddy', hasRow: false));
    await container.read(buddyProvider.future);
    await container.read(profileProvider.notifier).fetchProfile();
    container.read(notificationSyncProvider);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => mockNotificationRepo.syncNotifications(profile, buddyName: null),
    ).called(1);
  });

  test('renaming the Buddy re-triggers sync; same name does not', () async {
    final profile = testUserProfile();
    when(
      () => mockProfileRepo.getProfile(any()),
    ).thenAnswer((_) async => profile);
    when(
      () => mockNotificationRepo.syncNotifications(
        any(),
        buddyName: any(named: 'buddyName'),
      ),
    ).thenAnswer((_) async {});

    final fake = _FakeBuddy(_status('Pünktchen'));
    final container = makeContainer(fakeBuddy: fake);
    await container.read(buddyProvider.future);
    await container.read(profileProvider.notifier).fetchProfile();
    container.listen(notificationSyncProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    fake.emit(_status('Pünktchen'));
    await Future<void>.delayed(Duration.zero);
    verify(
      () => mockNotificationRepo.syncNotifications(
        profile,
        buddyName: 'Pünktchen',
      ),
    ).called(1);

    fake.emit(_status('Krümel'));
    await Future<void>.delayed(Duration.zero);
    verify(
      () =>
          mockNotificationRepo.syncNotifications(profile, buddyName: 'Krümel'),
    ).called(1);
  });
}
