import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/plus_status.dart';
import 'revenuecat_gateway.dart';

/// The monthly Plus subscription as the store offers it to this user.
class PlusOffer {
  const PlusOffer({
    required this.priceString,
    required this.trialDays,
    required this.handle,
  });

  /// The store's localized price, e.g. „6,90 €". Never build it in the app.
  final String priceString;

  /// Length of the free trial in days; null when the user is not eligible
  /// (or the product has no free trial).
  final int? trialDays;

  /// Opaque store object the gateway buys with; only the gateway reads it.
  final Object handle;
}

/// What came of a purchase or a restore.
sealed class PurchaseOutcome {
  const PurchaseOutcome();
}

/// The store confirmed; [status] is the resulting Plus status (for a restore
/// that found nothing: [PlusStatus.none]).
final class PurchaseDone extends PurchaseOutcome {
  const PurchaseDone(this.status);
  final PlusStatus status;
}

/// The user backed out of the store sheet.
final class PurchaseCancelled extends PurchaseOutcome {
  const PurchaseCancelled();
}

/// Waiting for approval (Ask to Buy, slow payment method).
final class PurchasePending extends PurchaseOutcome {
  const PurchasePending();
}

/// Anything else went wrong; the user was not charged.
final class PurchaseFailed extends PurchaseOutcome {
  const PurchaseFailed();
}

/// Thrown when the gateway is used although [PurchasesGateway.available] is
/// false or it was never configured.
class PurchasesUnavailable implements Exception {
  const PurchasesUnavailable();

  @override
  String toString() => 'PurchasesUnavailable';
}

/// The store purchase SDK, behind an interface so nothing else depends on it.
///
/// Callers configure once with the signed-in user's id (never anonymously)
/// and switch users with [logIn]; a sign-out calls nothing (R12). [logOut]
/// is used only after a successful account deletion (R18). Every other call
/// before [configure] throws [PurchasesUnavailable].
abstract interface class PurchasesGateway {
  /// False when this build has no SDK key for the platform.
  bool get available;

  Future<void> configure(String appUserId);
  Future<void> logIn(String appUserId);
  Future<void> logOut();

  /// Current status of the `plus` entitlement.
  Future<PlusStatus> status();

  /// Status pushed by the SDK whenever the customer info changes.
  Stream<PlusStatus> get statusChanges;

  /// The current offering's monthly package; null if there is none.
  Future<PlusOffer?> offer();

  Future<PurchaseOutcome> purchase(PlusOffer offer);

  /// [PurchaseDone] with [PlusStatus.none] when nothing was found.
  Future<PurchaseOutcome> restore();
}

final purchasesGatewayProvider = Provider<PurchasesGateway>((ref) {
  final gateway = RevenueCatGateway();
  ref.onDispose(gateway.dispose);
  return gateway;
});
