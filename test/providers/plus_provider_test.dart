import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belly_buddy/models/app_config.dart';
import 'package:belly_buddy/models/plus_status.dart';
import 'package:belly_buddy/providers/app_config_provider.dart';
import 'package:belly_buddy/providers/auth_provider.dart';
import 'package:belly_buddy/providers/plus_provider.dart';
import 'package:belly_buddy/repositories/auth_repository.dart';
import 'package:belly_buddy/services/edge_function_service.dart';
import 'package:belly_buddy/services/purchases/purchases_gateway.dart';

import '../helpers/app_lifecycle.dart';
import '../helpers/mocks.dart';
import '../helpers/purchases_fakes.dart';
import '../helpers/riverpod_helpers.dart';

const _a = 'user-a';
const _b = 'user-b';

const _trial = PlusStatus(state: PlusState.trial);
const _active = PlusStatus(state: PlusState.active);
const _lapsed = PlusStatus(state: PlusState.lapsed);

final _switch = NotifierProvider<Switchable<bool>, bool>(
  () => Switchable(true),
);

AppConfig _config(bool on) =>
    AppConfig(minimum: '0.0.0', latest: '0.0.0', paywallEnabled: on);

/// Lets the microtask/event queue drain so provider futures settle.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  // The status retries on the AppLifecycleListener's return to the
  // foreground, which needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePurchasesGateway gateway;
  late MockEdgeFunctionService edge;
  late SwitchableUserId user;
  late MockAuthRepository authRepo;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    gateway = FakePurchasesGateway();
    edge = MockEdgeFunctionService();
    when(
      () => edge.invoke(any(), body: any(named: 'body')),
    ).thenAnswer((_) async => {'plus': true, 'expires_at': null});
    user = SwitchableUserId(_a);
    authRepo = MockAuthRepository();
  });

  tearDown(() => gateway.dispose());

  ProviderContainer make({
    bool on = true,
    String? userId = _a,
    Object? configError,
  }) {
    user = SwitchableUserId(userId);
    final c = createContainer(
      overrides: [
        user.override,
        authRepositoryProvider.overrideWithValue(authRepo),
        purchasesGatewayProvider.overrideWithValue(gateway),
        edgeFunctionServiceProvider.overrideWithValue(edge),
        appConfigProvider.overrideWith((ref) async {
          if (configError != null) throw configError;
          return _config(ref.watch(_switch));
        }),
      ],
    );
    c.read(_switch.notifier).set(on);
    // Keep the providers alive like a mounted screen would.
    c.listen(plusAccessProvider, (_, _) {});
    c.listen(plusProvider, (_, _) {});
    return c;
  }

  Future<PlusStatus> statusOf(ProviderContainer c) async {
    await c.read(appConfigProvider.future).catchError((_) => _config(false));
    return c.read(plusProvider.future);
  }

  group('paywallEnabledProvider', () {
    test('off while the config loads', () {
      final loading = make();
      expect(loading.read(paywallEnabledProvider), isFalse);
    });

    test('config error counts as switch off', () async {
      final c = make(configError: Exception('offline'));
      await _settle();
      expect(c.read(paywallEnabledProvider), isFalse);
      expect(c.read(plusAccessProvider), PlusAccess.open);
      expect(gateway.calls, isEmpty);
    });

    test('config says on', () async {
      final c = make();
      await c.read(appConfigProvider.future);
      expect(c.read(paywallEnabledProvider), isTrue);
    });
  });

  test('switch off: gateway never configured, access open', () async {
    final c = make(on: false);
    final status = await statusOf(c);
    await _settle();

    expect(status.state, PlusState.none);
    expect(c.read(plusAccessProvider), PlusAccess.open);
    expect(c.read(paywallEnabledProvider), isFalse);
    expect(gateway.calls, isEmpty);
  });

  test('switch on, signed out: no gateway call, access open', () async {
    final c = make(userId: null);
    final status = await statusOf(c);
    await _settle();

    expect(status.state, PlusState.none);
    expect(c.read(plusAccessProvider), PlusAccess.open);
    expect(gateway.calls, isEmpty);
  });

  test('no SDK key: no gateway call, none, access open (R14)', () async {
    gateway.available = false;
    final c = make();
    final status = await statusOf(c);

    expect(status.state, PlusState.none);
    expect(gateway.calls, isEmpty);
    expect(c.read(plusAccessProvider), PlusAccess.open);
  });

  test('first user configures with the Supabase id', () async {
    gateway.statusAnswer = _active;
    final c = make();
    final status = await statusOf(c);

    expect(status.state, PlusState.active);
    expect(gateway.calls, ['configure:$_a', 'status']);
  });

  test('switching the switch off and on again configures only once', () async {
    final c = make();
    await statusOf(c);
    c.read(_switch.notifier).set(false);
    await statusOf(c);
    c.read(_switch.notifier).set(true);
    await statusOf(c);

    expect(gateway.callsNamed('configure'), ['configure:$_a']);
    expect(gateway.callsNamed('logIn'), isEmpty);
  });

  test("second user logs in, never sees the first user's status", () async {
    final lateA = gateway.holdNextStatus();
    final c = make();
    await c.read(appConfigProvider.future);
    await _settle();
    expect(gateway.calls, ['configure:$_a', 'status']);

    final seen = <PlusStatus?>[];
    c.listen(plusProvider, (_, next) => seen.add(next.value));

    gateway.statusAnswer = _trial;
    user.set(c, _b);
    final status = await c.read(plusProvider.future);
    lateA.complete(_active); // A's answer arrives late
    await _settle();

    expect(status.state, PlusState.trial);
    expect(c.read(plusProvider).value?.state, PlusState.trial);
    expect(seen.map((s) => s?.state), isNot(contains(PlusState.active)));
    expect(gateway.calls, ['configure:$_a', 'status', 'logIn:$_b', 'status']);
  });

  test("after a switch, the previous user's loaded status is not shown "
      'while the new one loads', () async {
    gateway.statusAnswer = _active;
    final c = make();
    await statusOf(c);

    final seen = <PlusState?>[];
    c.listen(plusProvider, (_, next) => seen.add(next.value?.state));
    final heldB = gateway.holdNextStatus();
    user.set(c, _b);
    await _settle();

    expect(c.read(plusProvider).isLoading, isTrue);
    expect(c.read(plusProvider).value?.state, isNot(PlusState.active));
    expect(seen, isNot(contains(PlusState.active)));
    expect(c.read(plusAccessProvider), PlusAccess.open);
    heldB.complete(PlusStatus.none);
    expect((await c.read(plusProvider.future)).state, PlusState.none);
    expect(c.read(plusAccessProvider), PlusAccess.locked);
  });

  test('a user switch while configure runs: one configure, then logIn '
      '(never two configures at once)', () async {
    final configuring = gateway.holdNextConfigure();
    final c = make();
    await c.read(appConfigProvider.future);
    await _settle();
    expect(gateway.calls, ['configure:$_a']);

    user.set(c, _b);
    await _settle();
    expect(gateway.calls, ['configure:$_a'], reason: 'waits for configure');

    configuring.complete();
    await c.read(plusProvider.future);
    await _settle();
    expect(gateway.calls, ['configure:$_a', 'logIn:$_b', 'status']);
  });

  test('sign-out makes no gateway call and answers none; the next user is '
      'logged in with logIn(newId)', () async {
    gateway.statusAnswer = _active;
    final c = make();
    await statusOf(c);
    final before = List.of(gateway.calls);

    user.set(c, null);
    final out = await c.read(plusProvider.future);
    await _settle();
    expect(out.state, PlusState.none);
    expect(gateway.calls, before);
    expect(gateway.callsNamed('logOut'), isEmpty);
    expect(c.read(plusAccessProvider), PlusAccess.open);

    gateway.statusAnswer = _lapsed;
    user.set(c, _b);
    final next = await c.read(plusProvider.future);
    expect(next.state, PlusState.lapsed);
    expect(gateway.calls, [...before, 'logIn:$_b', 'status']);
    expect(gateway.callsNamed('configure'), ['configure:$_a']);
    expect(gateway.callsNamed('logOut'), isEmpty);
  });

  test('the same user signing in again needs no logIn', () async {
    final c = make();
    await statusOf(c);
    user.set(c, null);
    await c.read(plusProvider.future);
    user.set(c, _a);
    await c.read(plusProvider.future);

    expect(gateway.calls, ['configure:$_a', 'status', 'status']);
  });

  test('status changes stream updates the state', () async {
    final c = make();
    await statusOf(c);
    expect(c.read(plusAccessProvider), PlusAccess.locked);

    gateway.emit(_trial);
    await _settle();
    expect(c.read(plusProvider).value?.state, PlusState.trial);
    expect(c.read(plusAccessProvider), PlusAccess.open);
  });

  test(
    'status changes after sign-out are ignored (subscription cancelled)',
    () async {
      final c = make();
      await statusOf(c);
      user.set(c, null);
      await c.read(plusProvider.future);

      gateway.emit(_active);
      await _settle();
      expect(c.read(plusProvider).value?.state, PlusState.none);
      expect(gateway.statusController.hasListener, isFalse);
    },
  );

  test('a push while status() runs is not overwritten by its answer', () async {
    final held = gateway.holdNextStatus();
    final c = make();
    await c.read(appConfigProvider.future);
    await _settle();
    expect(gateway.calls, ['configure:$_a', 'status']);

    gateway.emit(_trial);
    await _settle();
    held.complete(PlusStatus.none); // older answer
    final status = await c.read(plusProvider.future);

    expect(status.state, PlusState.trial);
    expect(c.read(plusProvider).value?.state, PlusState.trial);
  });

  // A sign-out (and the rebuild it causes) at any point right after
  // configure: the gone build never subscribes (and never throws on its
  // unmounted ref).
  for (var depth = 0; depth < 12; depth++) {
    test('sign-out $depth microtasks after configure leaves no '
        'subscription', () async {
      final configuring = gateway.holdNextConfigure();
      final c = make();
      await c.read(appConfigProvider.future);
      await _settle();

      void signOutAfter(int n) => n == 0
          ? (user..set(c, null), c.read(plusProvider))
          : scheduleMicrotask(() => signOutAfter(n - 1));
      configuring.complete();
      signOutAfter(depth);
      await _settle();
      await _settle();

      expect(gateway.statusController.hasListener, isFalse);
      expect((await c.read(plusProvider.future)).state, PlusState.none);
    });
  }

  group('plusAccessProvider', () {
    for (final (status, access) in [
      (PlusStatus.none, PlusAccess.locked),
      (_lapsed, PlusAccess.locked),
      (_trial, PlusAccess.open),
      (_active, PlusAccess.open),
    ]) {
      test('${status.state.name} -> ${access.name}', () async {
        gateway.statusAnswer = status;
        final c = make();
        await statusOf(c);
        expect(c.read(plusAccessProvider), access);
      });
    }

    test('none with a management url still locks (state, not ==)', () async {
      gateway.statusAnswer = const PlusStatus(
        state: PlusState.none,
        managementUrl: 'https://apps.apple.com/account/subscriptions',
      );
      final c = make();
      await statusOf(c);
      expect(c.read(plusAccessProvider), PlusAccess.locked);
    });

    test('loading opens', () async {
      gateway.holdNextStatus();
      final c = make();
      await c.read(appConfigProvider.future);
      await _settle();
      expect(c.read(plusProvider).isLoading, isTrue);
      expect(c.read(plusAccessProvider), PlusAccess.open);
    });

    for (final (name, script)
        in <(String, void Function(FakePurchasesGateway))>[
          ('status', (g) => g.statusError = PlatformException(code: '10')),
          (
            'configure',
            (g) => g.configureError = PlatformException(code: '10'),
          ),
        ]) {
      test('$name error opens', () async {
        script(gateway);
        final c = make();
        await c.read(appConfigProvider.future);
        await _settle();
        expect(c.read(plusProvider).hasError, isTrue);
        expect(c.read(plusAccessProvider), PlusAccess.open);
      });
    }

    test(
      'logIn error opens, and the old user is not kept as identity',
      () async {
        gateway.statusAnswer = _active;
        final c = make();
        await statusOf(c);
        gateway.logInError = PlatformException(code: '10');
        user.set(c, _b);
        await _settle();
        await _settle();
        expect(c.read(plusProvider).hasError, isTrue);
        expect(c.read(plusAccessProvider), PlusAccess.open);

        // A status push while the identity is unknown is not applied.
        gateway.emit(_active);
        await _settle();
        expect(c.read(plusProvider).hasError, isTrue);
      },
    );

    test('a failed logIn is repaired by the paywall\'s identify: the status '
        'loads, and pushes count again', () async {
      final c = make();
      await statusOf(c);
      gateway.logInError = PlatformException(code: '10');
      user.set(c, _b);
      await _settle();
      await _settle();
      expect(c.read(plusProvider).hasError, isTrue);

      gateway
        ..logInError = null
        ..statusAnswer = _trial;
      c.listen(plusOfferProvider, (_, _) {});
      await c.read(plusOfferProvider.future);
      expect(await c.read(plusProvider.future), _trial);
      expect(gateway.callsNamed('logIn'), ['logIn:$_b', 'logIn:$_b']);

      gateway.emit(_active);
      await _settle();
      expect(c.read(plusProvider).value, _active);
    });

    test('a failed configure is tried again on the return to the '
        'foreground', () async {
      gateway.configureError = PlatformException(code: '10');
      final c = make();
      await c.read(appConfigProvider.future);
      await _settle();
      expect(c.read(plusProvider).hasError, isTrue);

      gateway
        ..configureError = null
        ..statusAnswer = _active;
      returnFromBackground();
      expect(await c.read(plusProvider.future), _active);
      expect(gateway.callsNamed('configure'), [
        'configure:$_a',
        'configure:$_a',
      ]);
    });

    test(
      'a loaded status is not reloaded on the return to the foreground',
      () async {
        final c = make();
        await statusOf(c);
        final before = List.of(gateway.calls);
        returnFromBackground();
        await _settle();
        expect(gateway.calls, before);
      },
    );

    test('switch off: the return to the foreground calls nothing', () async {
      final c = make(on: false);
      await statusOf(c);
      returnFromBackground();
      await _settle();
      expect(gateway.calls, isEmpty);
    });

    test('a failed configure is tried again on the next build', () async {
      gateway.configureError = PlatformException(code: '10');
      final c = make();
      await c.read(appConfigProvider.future);
      await _settle();
      gateway.configureError = null;
      c.invalidate(plusProvider);
      await c.read(plusProvider.future);
      expect(gateway.callsNamed('configure'), [
        'configure:$_a',
        'configure:$_a',
      ]);
      expect(gateway.callsNamed('logIn'), isEmpty);
    });
  });

  group('purchase and restore', () {
    test('purchase done calls plus-sync; a failing plus-sync still returns '
        'done', () async {
      final c = make();
      await statusOf(c);
      final notifier = c.read(plusProvider.notifier);

      final done = await notifier.purchase(testPlusOffer());
      expect(done, isA<PurchaseDone>());
      expect(c.read(plusProvider).value?.state, PlusState.trial);
      expect(c.read(plusAccessProvider), PlusAccess.open);
      verify(() => edge.invoke('plus-sync')).called(1);

      when(
        () => edge.invoke(any(), body: any(named: 'body')),
      ).thenThrow(Exception('502'));
      gateway.purchaseAnswer = const PurchaseDone(_active);
      final again = await notifier.purchase(testPlusOffer());
      expect(again, isA<PurchaseDone>());
      expect(c.read(plusProvider).value?.state, PlusState.active);
    });

    test('restore done sets the state and calls plus-sync', () async {
      gateway.restoreAnswer = const PurchaseDone(_active);
      final c = make();
      await statusOf(c);

      final done = await c.read(plusProvider.notifier).restore();
      expect(done, isA<PurchaseDone>());
      expect(c.read(plusProvider).value?.state, PlusState.active);
      verify(() => edge.invoke('plus-sync')).called(1);
    });

    for (final outcome in const <PurchaseOutcome>[
      PurchaseCancelled(),
      PurchasePending(),
      PurchaseFailed(),
    ]) {
      test('${outcome.runtimeType}: state unchanged, no plus-sync', () async {
        gateway.purchaseAnswer = outcome;
        final c = make();
        await statusOf(c);

        final result = await c
            .read(plusProvider.notifier)
            .purchase(testPlusOffer());
        expect(result.runtimeType, outcome.runtimeType);
        expect(c.read(plusProvider).value?.state, PlusState.none);
        verifyNever(() => edge.invoke(any(), body: any(named: 'body')));
      });
    }

    test('switch off: purchase fails without a gateway call', () async {
      final c = make(on: false);
      await statusOf(c);
      final result = await c
          .read(plusProvider.notifier)
          .purchase(testPlusOffer());
      expect(result, isA<PurchaseFailed>());
      expect(gateway.calls, isEmpty);
    });

    test('signed out: restore fails without a gateway call', () async {
      final c = make(userId: null);
      await statusOf(c);
      final result = await c.read(plusProvider.notifier).restore();
      expect(result, isA<PurchaseFailed>());
      expect(gateway.calls, isEmpty);
    });

    test('a gateway exception becomes PurchaseFailed', () async {
      final c = make();
      await statusOf(c);
      // Not configured for this user any more (e.g. logIn failed).
      gateway.logInError = PlatformException(code: '10');
      user.set(c, _b);
      await _settle();
      final result = await c
          .read(plusProvider.notifier)
          .purchase(testPlusOffer());
      expect(result, isA<PurchaseFailed>());
      expect(gateway.callsNamed('purchase'), isEmpty);
    });

    test(
      'a purchase finishing after the user changed is not applied',
      () async {
        final c = make();
        await statusOf(c);
        final sheet = gateway.holdNextPurchase();
        final pending = c.read(plusProvider.notifier).purchase(testPlusOffer());
        await _settle();

        user.set(c, _b);
        await c.read(plusProvider.future);
        sheet.complete(const PurchaseDone(_active));
        final result = await pending;
        await _settle();

        expect(result, isA<PurchaseCancelled>());
        expect(c.read(plusProvider).value?.state, PlusState.none);
        verifyNever(() => edge.invoke(any(), body: any(named: 'body')));
      },
    );

    test('a rebuild for the same user during the purchase still applies it '
        'and syncs', () async {
      final c = make();
      await statusOf(c);
      final sheet = gateway.holdNextPurchase();
      final pending = c.read(plusProvider.notifier).purchase(testPlusOffer());
      await _settle();

      c.invalidate(plusProvider);
      await c.read(plusProvider.future);
      sheet.complete(const PurchaseDone(_active));
      final result = await pending;

      expect(result, isA<PurchaseDone>());
      expect(c.read(plusProvider).value?.state, PlusState.active);
      verify(() => edge.invoke('plus-sync')).called(1);
    });
  });

  group('plusOfferProvider', () {
    test('switch off: null without a gateway call', () async {
      final c = make(on: false);
      await c.read(appConfigProvider.future);
      expect(await c.read(plusOfferProvider.future), isNull);
      expect(gateway.calls, isEmpty);
    });

    test('no SDK key: null without a gateway call', () async {
      gateway.available = false;
      final c = make();
      await c.read(appConfigProvider.future);
      expect(await c.read(plusOfferProvider.future), isNull);
      expect(gateway.calls, isEmpty);
    });

    test('signed out: null without a gateway call', () async {
      final c = make(userId: null);
      await c.read(appConfigProvider.future);
      expect(await c.read(plusOfferProvider.future), isNull);
      expect(gateway.calls, isEmpty);
    });

    test('switch on: the store offer, after configure', () async {
      gateway.offerAnswer = testPlusOffer();
      final c = make();
      await c.read(appConfigProvider.future);
      final sub = c.listen(plusOfferProvider, (_, _) {});
      final offer = await c.read(plusOfferProvider.future);
      sub.close();

      expect(offer?.priceString, '6,90 €');
      expect(offer?.trialDays, 14);
      expect(gateway.calls.first, 'configure:$_a');
      expect(gateway.callsNamed('configure'), hasLength(1));
      expect(gateway.calls.indexOf('offer'), greaterThan(0));
    });

    test('a delayed offer answer arrives', () async {
      final held = gateway.holdNextOffer();
      final c = make();
      await c.read(appConfigProvider.future);
      final sub = c.listen(plusOfferProvider, (_, _) {});
      await _settle();
      expect(c.read(plusOfferProvider).isLoading, isTrue);
      held.complete(testPlusOffer(trialDays: null));
      final offer = await c.read(plusOfferProvider.future);
      sub.close();
      expect(offer?.trialDays, isNull);
    });
  });

  group('account deletion logs the SDK out (R18)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    /// Deletes the account the way the app does: the auth call succeeds
    /// (or throws [error]) and the session ends.
    Future<void> delete(ProviderContainer c, {Object? error}) async {
      when(() => authRepo.deleteAccount()).thenAnswer((_) async {
        if (error != null) throw error;
        user.set(c, null);
      });
      when(() => authRepo.currentUser).thenReturn(null);
      final future = c.read(authNotifierProvider.notifier).deleteAccount();
      if (error != null) {
        await expectLater(future, throwsA(error));
      } else {
        await future;
      }
      await _settle();
    }

    test('configured: logOut once after a successful deletion', () async {
      gateway.statusAnswer = _active;
      final c = make();
      await statusOf(c);

      await delete(c);
      expect(gateway.callsNamed('logOut'), ['logOut']);
      expect(c.read(authNotifierProvider), isA<AsyncData<void>>());

      // The next user is logged in again (the identity was forgotten).
      user.set(c, _b);
      await c.read(plusProvider.future);
      expect(gateway.callsNamed('logIn'), ['logIn:$_b']);
    });

    test('a failing logOut is ignored: the deletion still succeeds', () async {
      gateway.logOutError = Exception('offline');
      final c = make();
      await statusOf(c);

      await delete(c);
      expect(gateway.callsNamed('logOut'), ['logOut']);
      expect(c.read(authNotifierProvider), isA<AsyncData<void>>());
    });

    test('never configured (switch off): no logOut', () async {
      final c = make(on: false);
      await statusOf(c);

      await delete(c);
      expect(gateway.calls, isEmpty);
    });

    test('never configured (no SDK key): no logOut', () async {
      gateway.available = false;
      final c = make();
      await statusOf(c);

      await delete(c);
      expect(gateway.calls, isEmpty);
    });

    test('failed deletion: no logOut', () async {
      final c = make();
      await statusOf(c);

      await delete(c, error: Exception('offline'));
      expect(gateway.callsNamed('logOut'), isEmpty);
    });

    test('plain sign-out: still no logOut (R12)', () async {
      final c = make();
      await statusOf(c);
      when(() => authRepo.signOut()).thenAnswer((_) async => user.set(c, null));
      when(() => authRepo.currentUser).thenReturn(null);

      await c.read(authNotifierProvider.notifier).signOut();
      await _settle();
      expect(gateway.callsNamed('logOut'), isEmpty);
    });
  });
}
