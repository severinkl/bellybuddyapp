import 'dart:async';

// ignore_for_file: invalid_use_of_internal_member
import 'package:riverpod/src/internals.dart' show Override;

import 'package:belly_buddy/models/plus_status.dart';
import 'package:belly_buddy/providers/plus_provider.dart';
import 'package:belly_buddy/services/purchases/purchases_gateway.dart';

/// A [PlusOffer] with defaults: 6,90 € a month, 14 trial days.
PlusOffer testPlusOffer({
  String priceString = '6,90 €',
  int? trialDays = 14,
  Object handle = 'monthly',
}) => PlusOffer(priceString: priceString, trialDays: trialDays, handle: handle);

/// Scriptable [PurchasesGateway] that records every call.
///
/// [calls] holds entries like `'configure:u1'`, `'logIn:u2'`, `'logOut'`,
/// `'status'`, `'offer'`, `'purchase:6,90 €'`, `'restore'`.
///
/// Status answers: [statusAnswer] by default; [statusQueue] (first in, first
/// out) takes precedence — put a [Completer] future there to answer later,
/// e.g. to prove a late answer for the previous user is dropped. Use
/// [holdNextStatus] for that. [statusError] makes [status] throw.
///
/// [configureError] / [logInError] / [logOutError] make those calls throw (recorded first);
/// [holdNextConfigure], [holdNextLogIn], [holdNextOffer], [holdNextPurchase]
/// and [holdNextRestore] make the next such call answer only when the
/// returned completer completes (a purchase sheet still open, a slow
/// network).
class FakePurchasesGateway implements PurchasesGateway {
  FakePurchasesGateway({
    this.available = true,
    this.statusAnswer = PlusStatus.none,
    this.offerAnswer,
    this.purchaseAnswer = const PurchaseDone(
      PlusStatus(state: PlusState.trial),
    ),
    this.restoreAnswer = const PurchaseDone(PlusStatus.none),
  });

  @override
  bool available;

  PlusStatus statusAnswer;
  Object? statusError;
  final statusQueue = <Future<PlusStatus>>[];

  PlusOffer? offerAnswer;
  Object? offerError;
  PurchaseOutcome purchaseAnswer;
  PurchaseOutcome restoreAnswer;

  Object? configureError;
  Object? logInError;
  Object? logOutError;
  final _configureQueue = <Future<void>>[];
  final _logInQueue = <Future<void>>[];
  final _offerQueue = <Future<PlusOffer?>>[];
  final _purchaseQueue = <Future<PurchaseOutcome>>[];
  final _restoreQueue = <Future<PurchaseOutcome>>[];

  final calls = <String>[];
  final statusController = StreamController<PlusStatus>.broadcast();

  /// The offers passed to [purchase], in order.
  final purchasedOffers = <PlusOffer>[];

  List<String> callsNamed(String name) =>
      calls.where((c) => c == name || c.startsWith('$name:')).toList();

  /// Queues a status answer that arrives only when the returned completer
  /// completes.
  Completer<PlusStatus> holdNextStatus() {
    final completer = Completer<PlusStatus>();
    statusQueue.add(completer.future);
    return completer;
  }

  Completer<void> holdNextConfigure() => _hold(_configureQueue);
  Completer<void> holdNextLogIn() => _hold(_logInQueue);
  Completer<PlusOffer?> holdNextOffer() => _hold(_offerQueue);
  Completer<PurchaseOutcome> holdNextPurchase() => _hold(_purchaseQueue);
  Completer<PurchaseOutcome> holdNextRestore() => _hold(_restoreQueue);

  static Completer<T> _hold<T>(List<Future<T>> queue) {
    final completer = Completer<T>();
    queue.add(completer.future);
    return completer;
  }

  /// Pushes [status] to [statusChanges] as the SDK listener would.
  void emit(PlusStatus status) => statusController.add(status);

  @override
  Future<void> configure(String appUserId) async {
    calls.add('configure:$appUserId');
    final error = configureError;
    if (error != null) throw error;
    if (_configureQueue.isNotEmpty) await _configureQueue.removeAt(0);
  }

  @override
  Future<void> logIn(String appUserId) async {
    calls.add('logIn:$appUserId');
    final error = logInError;
    if (error != null) throw error;
    if (_logInQueue.isNotEmpty) await _logInQueue.removeAt(0);
  }

  @override
  Future<void> logOut() async {
    calls.add('logOut');
    final error = logOutError;
    if (error != null) throw error;
  }

  @override
  Future<PlusStatus> status() {
    calls.add('status');
    final error = statusError;
    if (error != null) return Future.error(error);
    if (statusQueue.isNotEmpty) return statusQueue.removeAt(0);
    return Future.value(statusAnswer);
  }

  @override
  Stream<PlusStatus> get statusChanges => statusController.stream;

  @override
  Future<PlusOffer?> offer() async {
    calls.add('offer');
    final error = offerError;
    if (error != null) throw error;
    if (_offerQueue.isNotEmpty) return _offerQueue.removeAt(0);
    return offerAnswer;
  }

  @override
  Future<PurchaseOutcome> purchase(PlusOffer offer) async {
    calls.add('purchase:${offer.priceString}');
    purchasedOffers.add(offer);
    if (_purchaseQueue.isNotEmpty) return _purchaseQueue.removeAt(0);
    return purchaseAnswer;
  }

  @override
  Future<PurchaseOutcome> restore() async {
    calls.add('restore');
    if (_restoreQueue.isNotEmpty) return _restoreQueue.removeAt(0);
    return restoreAnswer;
  }

  Future<void> dispose() => statusController.close();
}

/// A [PlusNotifier] that answers [answer] instead of asking the SDK.
class FakePlusNotifier extends PlusNotifier {
  FakePlusNotifier(this.answer);

  /// Always answers [status].
  FakePlusNotifier.status(PlusStatus status) : answer = (() async => status);

  final Future<PlusStatus> Function() answer;

  @override
  Future<PlusStatus> build() => answer();
}

/// Plus is locked (the switch is on, the user has no Plus).
final plusLockedOverrides = <Override>[
  plusAccessProvider.overrideWithValue(PlusAccess.locked),
];

/// Plus is usable.
final plusOpenOverrides = <Override>[
  plusAccessProvider.overrideWithValue(PlusAccess.open),
];

/// The remote Plus switch is off.
final plusSwitchOffOverrides = <Override>[
  paywallEnabledProvider.overrideWithValue(false),
];
