// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:belly_buddy/models/user_profile.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/profile_provider.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/widgets/common/weekly_tips_switch.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixtures.dart';

class _Seeded extends ProfileNotifier {
  _Seeded(this._profile);
  final UserProfile _profile;

  @override
  AsyncValue<UserProfile?> build() => AsyncValue.data(_profile);
}

/// A repository whose weekly-tips write waits for [release].
class _SlowRepo extends FakeProfileRepository {
  final release = Completer<void>();

  @override
  Future<void> setWeeklyTips(String userId, bool enabled) async {
    await super.setWeeklyTips(userId, enabled);
    await release.future;
  }
}

void main() {
  late FakeProfileRepository repo;

  Future<void> pump(WidgetTester tester, {FakeProfileRepository? using}) async {
    repo = using ?? FakeProfileRepository();
    final profile = testUserProfile();
    repo.seedProfile(profile);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(testUserId),
          profileProvider.overrideWith(() => _Seeded(profile)),
        ],
        child: const MaterialApp(home: Scaffold(body: WeeklyTipsSwitch())),
      ),
    );
    await tester.pump();
  }

  bool isOn(WidgetTester tester) => tester
      .widget<SwitchListTile>(find.byKey(WeeklyTipsSwitch.switchKey))
      .value;

  testWidgets('shows the title and the sentence', (tester) async {
    await pump(tester);

    expect(find.text('Wöchentliche Tipps'), findsOneWidget);
    expect(find.text(WeeklyTipsSwitch.sentence), findsOneWidget);
    expect(isOn(tester), isFalse);
  });

  testWidgets('flipping it on saves true', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(WeeklyTipsSwitch.switchKey));
    await tester.pumpAndSettle();

    expect(repo.weeklyTipsWrites, [true]);
    expect(isOn(tester), isTrue);
  });

  testWidgets('failure snaps back with a SnackBar', (tester) async {
    await pump(tester, using: FakeProfileRepository());
    repo.weeklyTipsError = const PostgrestException(message: 'no column');

    await tester.tap(find.byKey(WeeklyTipsSwitch.switchKey));
    await tester.pumpAndSettle();

    expect(isOn(tester), isFalse);
    expect(find.text(WeeklyTipsSwitch.failure), findsOneWidget);
  });

  testWidgets('a second tap while saving is ignored', (tester) async {
    final slow = _SlowRepo();
    await pump(tester, using: slow);

    await tester.tap(find.byKey(WeeklyTipsSwitch.switchKey));
    await tester.pump();
    await tester.tap(find.byKey(WeeklyTipsSwitch.switchKey));
    await tester.pump();
    slow.release.complete();
    await tester.pumpAndSettle();

    expect(slow.weeklyTipsWrites, [true]);
  });
}
