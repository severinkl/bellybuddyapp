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
        fakeRepo.seedProfile(testUserProfile(alreadySeenTutorial: false));
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
      fakeRepo.seedProfile(testUserProfile(alreadySeenTutorial: false));
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

  group('TutorialNotifier replay', () {
    test('consumeReplay is false without a request', () {
      final c = makeContainer();

      expect(c.read(tutorialProvider.notifier).consumeReplay(), isFalse);
      expect(c.read(tutorialProvider), isFalse);
    });

    test('consumeReplay is true once', () {
      final c = makeContainer();
      final tutorial = c.read(tutorialProvider.notifier);

      tutorial.requestReplay();
      expect(c.read(tutorialProvider), isTrue);

      expect(tutorial.consumeReplay(), isTrue);
      expect(c.read(tutorialProvider), isFalse);
      expect(tutorial.consumeReplay(), isFalse);

      // Each new request is taken once again.
      tutorial
        ..requestReplay()
        ..requestReplay();
      expect(tutorial.consumeReplay(), isTrue);
      expect(tutorial.consumeReplay(), isFalse);
    });

    test('a pending replay ends with its user (sign-out, another user)', () {
      final user = NotifierProvider<_User, String?>(_User.new);
      final c = createContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(fakeRepo),
          currentUserIdProvider.overrideWith((ref) => ref.watch(user)),
        ],
      );
      // Kept alive like Home's listener keeps it.
      c.listen(tutorialProvider, (_, _) {});

      // Requested, then signed out before Home took it.
      c.read(tutorialProvider.notifier).requestReplay();
      c.read(user.notifier).set(null);
      expect(c.read(tutorialProvider), isFalse);

      // The next user gets no tour they never asked for.
      c.read(user.notifier).set('other-user');
      expect(c.read(tutorialProvider.notifier).consumeReplay(), isFalse);

      // Their own request still works.
      c.read(tutorialProvider.notifier).requestReplay();
      expect(c.read(tutorialProvider.notifier).consumeReplay(), isTrue);
    });
  });
}

/// The signed-in user's id, settable.
class _User extends Notifier<String?> {
  @override
  String? build() => testUserId;

  void set(String? id) => state = id;
}
