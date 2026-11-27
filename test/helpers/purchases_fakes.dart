import 'dart:async';

import 'package:belly_buddy/models/plus_status.dart';
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

  /// Pushes [status] to [statusChanges] as the SDK listener would.
  void emit(PlusStatus status) => statusController.add(status);

  @override
  Future<void> configure(String appUserId) async =>
      calls.add('configure:$appUserId');

  @override
  Future<void> logIn(String appUserId) async => calls.add('logIn:$appUserId');

  @override
  Future<void> logOut() async => calls.add('logOut');

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
    return offerAnswer;
  }

  @override
  Future<PurchaseOutcome> purchase(PlusOffer offer) async {
    calls.add('purchase:${offer.priceString}');
    purchasedOffers.add(offer);
    return purchaseAnswer;
  }

  @override
  Future<PurchaseOutcome> restore() async {
    calls.add('restore');
    return restoreAnswer;
  }

  Future<void> dispose() => statusController.close();
}
