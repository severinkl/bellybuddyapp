import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/providers/tutorial_provider.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/riverpod_helpers.dart';

void main() {
  late FakeProfileRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeProfileRepository();
  });

  ProviderContainer makeContainer({String? userId = testUserId}) =>
      createContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(fakeRepo),
          currentUserIdProvider.overrideWithValue(userId),
        ],
      );

  group('TutorialNotifier.shouldShow', () {
    test('returns false when profile has not loaded yet', () {
      final c = makeContainer();
      expect(c.read(tutorialProvider.notifier).shouldShow(), isFalse);
    });

    test(
      'returns true when profile loaded and tutorialSeenAt is null',
      () async {
        fakeRepo.seedProfile(testUserProfile(tutorialSeenAt: null));
        final c = makeContainer();
        await c.read(profileProvider.notifier).fetchProfile();

        expect(c.read(tutorialProvider.notifier).shouldShow(), isTrue);
      },
    );

    test('returns false when tutorialSeenAt is set', () async {
      fakeRepo.seedProfile(
        testUserProfile().copyWith(tutorialSeenAt: DateTime.utc(2026, 4, 1)),
      );
      final c = makeContainer();
      await c.read(profileProvider.notifier).fetchProfile();

      expect(c.read(tutorialProvider.notifier).shouldShow(), isFalse);
    });
  });

  group('TutorialNotifier.markSeen', () {
    test('writes a timestamp via the repo and refreshes the profile', () async {
      fakeRepo.seedProfile(testUserProfile(tutorialSeenAt: null));
      final c = makeContainer();
      await c.read(profileProvider.notifier).fetchProfile();

      final before = DateTime.now().toUtc();
      await c.read(tutorialProvider.notifier).markSeen();
      final after = DateTime.now().toUtc();

      expect(fakeRepo.tutorialUpdateCalled, isTrue);
      expect(fakeRepo.lastTutorialSeenAt, isNotNull);
      expect(
        fakeRepo.lastTutorialSeenAt!.isAtSameMomentAs(before) ||
            fakeRepo.lastTutorialSeenAt!.isAfter(before),
        isTrue,
      );
      expect(
        fakeRepo.lastTutorialSeenAt!.isBefore(after) ||
            fakeRepo.lastTutorialSeenAt!.isAtSameMomentAs(after),
        isTrue,
      );
      final profile = c.read(profileProvider).value;
      expect(profile?.tutorialSeenAt, equals(fakeRepo.lastTutorialSeenAt));
    });

    test('is a no-op if no user is signed in', () async {
      final c = makeContainer(userId: null);
      await c.read(tutorialProvider.notifier).markSeen();
      expect(fakeRepo.tutorialUpdateCalled, isFalse);
    });
  });

  group('TutorialNotifier.reset', () {
    test('writes null via the repo and refreshes the profile', () async {
      fakeRepo.seedProfile(
        testUserProfile().copyWith(tutorialSeenAt: DateTime.utc(2026, 4, 1)),
      );
      final c = makeContainer();
      await c.read(profileProvider.notifier).fetchProfile();

      await c.read(tutorialProvider.notifier).reset();

      expect(fakeRepo.tutorialUpdateCalled, isTrue);
      expect(fakeRepo.lastTutorialSeenAt, isNull);
      expect(c.read(profileProvider).value?.tutorialSeenAt, isNull);
    });
  });
}
