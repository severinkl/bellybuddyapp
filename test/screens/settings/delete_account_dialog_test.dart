// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/models/plus_status.dart';
import 'package:belly_buddy/providers/core_providers.dart';
import 'package:belly_buddy/providers/plus_provider.dart';
import 'package:belly_buddy/services/plus/plus_copy.dart';
import 'package:belly_buddy/services/purchases/purchases_gateway.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/repositories/profile_repository.dart';
import 'package:belly_buddy/screens/settings/widgets/delete_account_dialog.dart';

import '../../helpers/fakes.dart';
import '../../helpers/purchases_fakes.dart';
import '../../helpers/riverpod_helpers.dart';

class _FakePlus extends PlusNotifier {
  _FakePlus(this.status);
  final PlusStatus status;

  @override
  Future<PlusStatus> build() async => status;
}

class _CountingAuthRepository extends FakeAuthRepository {
  int deletes = 0;
  bool fail = false;

  @override
  Future<void> deleteAccount() async {
    deletes++;
    if (fail) throw Exception('delete failed');
  }
}

void main() {
  late _CountingAuthRepository auth;

  List<Override> overrides() => [
    authRepositoryProvider.overrideWithValue(auth),
    profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
    currentUserIdProvider.overrideWithValue(null),
  ];

  setUp(() => auth = _CountingAuthRepository());

  Future<void> openDialog(
    WidgetTester tester, {
    PlusStatus? plus,
    List<Override>? plusOverrides,
  }) async {
    await tester.pumpWithProviders(
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDeleteAccountDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
      overrides: [
        ...?plusOverrides,
        if (plusOverrides == null) ...[
          ...overrides(),
          paywallEnabledProvider.overrideWithValue(plus != null),
          if (plus != null) plusProvider.overrideWith(() => _FakePlus(plus)),
        ],
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  ElevatedButton deleteButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  group('isDeleteConfirmation', () {
    test('accepts LÖSCHEN, LOESCHEN and lowercase, trimmed', () {
      for (final typed in [
        'LÖSCHEN',
        'LOESCHEN',
        'löschen',
        'loeschen',
        'Löschen',
        ' LÖSCHEN ',
        // „Ö" typed as O plus a combining diaeresis.
        'LÖSCHEN',
      ]) {
        expect(isDeleteConfirmation(typed), isTrue, reason: typed);
      }
    });

    test('rejects anything else', () {
      for (final typed in ['', 'LOSCHEN', 'LÖSCHE', 'LÖSCHEN!', 'DELETE']) {
        expect(isDeleteConfirmation(typed), isFalse, reason: typed);
      }
    });
  });

  testWidgets('a lowercase „loeschen" enables the delete button', (
    tester,
  ) async {
    await openDialog(tester);
    expect(deleteButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'loeschen');
    await tester.pump();

    expect(deleteButton(tester).onPressed, isNotNull);
  });

  testWidgets('after deleting, „Dein Konto wurde gelöscht." shows', (
    tester,
  ) async {
    await openDialog(tester);
    await tester.enterText(find.byType(TextField), 'LÖSCHEN');
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(auth.deletes, 1);
    expect(find.text('Dein Konto wurde gelöscht.'), findsOneWidget);
    expect(find.text('Fehler beim Löschen.'), findsNothing);
  });

  testWidgets('a failed deletion says so and nothing else', (tester) async {
    auth.fail = true;
    await openDialog(tester);
    await tester.enterText(find.byType(TextField), 'LÖSCHEN');
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('Fehler beim Löschen.'), findsOneWidget);
    expect(find.text('Dein Konto wurde gelöscht.'), findsNothing);
  });

  group('subscription warning', () {
    for (final (name, status, shown) in [
      ('trial', const PlusStatus(state: PlusState.trial), true),
      ('active', const PlusStatus(state: PlusState.active), true),
      ('none', PlusStatus.none, false),
      ('lapsed', const PlusStatus(state: PlusState.lapsed), false),
      (
        'active with a payment problem',
        const PlusStatus(state: PlusState.active, billingIssue: true),
        true,
      ),
    ]) {
      testWidgets('$name: ${shown ? 'shown' : 'not shown'}', (tester) async {
        await openDialog(tester, plus: status);
        expect(
          find.text(PlusCopy.deleteWarning),
          shown ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('switch off: not shown, even for a store subscriber', (
      tester,
    ) async {
      // The real provider with a signed-in user whose store says active:
      // with the switch off it never asks the store and answers none.
      final gateway = FakePurchasesGateway(
        statusAnswer: const PlusStatus(state: PlusState.active),
      );
      addTearDown(gateway.dispose);
      await openDialog(
        tester,
        plusOverrides: [
          authRepositoryProvider.overrideWithValue(auth),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          currentUserIdProvider.overrideWithValue('u1'),
          paywallEnabledProvider.overrideWithValue(false),
          purchasesGatewayProvider.overrideWithValue(gateway),
        ],
      );
      expect(find.text(PlusCopy.deleteWarning), findsNothing);
      expect(gateway.calls, isEmpty);
    });

    test('wording', () {
      expect(
        PlusCopy.deleteWarning,
        'Dein Abo läuft über den Store weiter. Kündige es dort, sonst wird es '
        'weiter verrechnet.',
      );
    });
  });
}
