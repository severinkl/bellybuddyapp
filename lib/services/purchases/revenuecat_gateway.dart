import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../config/revenuecat_config.dart';
import '../../models/plus_status.dart';
import '../../utils/logger.dart';
import 'purchases_gateway.dart';

/// RevenueCat entitlement that unlocks Belly Buddy Plus.
const plusEntitlementId = 'plus';

const _log = AppLogger('Purchases');

/// [PlusStatus] from the `plus` entitlement of the customer info (pure).
///
/// Active in a trial period → trial; active otherwise → active; present but
/// inactive → lapsed; absent → none.
PlusStatus plusStatusOf(EntitlementInfo? info, {String? managementUrl}) {
  if (info == null) {
    return PlusStatus(state: PlusState.none, managementUrl: managementUrl);
  }
  final state = !info.isActive
      ? PlusState.lapsed
      : info.periodType == PeriodType.trial
      ? PlusState.trial
      : PlusState.active;
  final expiry = info.expirationDate;
  return PlusStatus(
    state: state,
    expiresAt: expiry == null ? null : DateTime.tryParse(expiry)?.toUtc(),
    willRenew: info.willRenew,
    billingIssue: info.billingIssueDetectedAt != null,
    managementUrl: managementUrl,
  );
}

/// Length of a store period in days (a month counts 30, a year 365); null for
/// an unknown unit or a non-positive length.
int? trialDaysOf(PeriodUnit unit, int count) {
  if (count <= 0) return null;
  final perUnit = switch (unit) {
    PeriodUnit.day => 1,
    PeriodUnit.week => 7,
    PeriodUnit.month => 30,
    PeriodUnit.year => 365,
    PeriodUnit.unknown => null,
  };
  return perUnit == null ? null : perUnit * count;
}

PlusStatus _statusOf(CustomerInfo info) => plusStatusOf(
  info.entitlements.all[plusEntitlementId],
  managementUrl: info.managementURL,
);

/// [PurchasesGateway] over `purchases_flutter` — the only file importing it.
///
/// No `Purchases.*` call happens before [configure], and [configure] refuses
/// when the platform key is empty, so with the switch off (nobody calls
/// [configure]) the SDK stays untouched.
class RevenueCatGateway implements PurchasesGateway {
  RevenueCatGateway({String? iosKey, String? androidKey})
    : _iosKey = iosKey ?? RevenueCatConfig.iosKey,
      _androidKey = androidKey ?? RevenueCatConfig.androidKey;

  final String _iosKey;
  final String _androidKey;
  final _changes = StreamController<PlusStatus>.broadcast();
  bool _configured = false;

  String get _key => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => _iosKey,
    TargetPlatform.android => _androidKey,
    _ => '',
  };

  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  bool get available => _key.isNotEmpty;

  @override
  Stream<PlusStatus> get statusChanges => _changes.stream;

  void _onCustomerInfo(CustomerInfo info) {
    if (!_changes.isClosed) _changes.add(_statusOf(info));
  }

  void _ensureConfigured() {
    if (!_configured) throw const PurchasesUnavailable();
  }

  @override
  Future<void> configure(String appUserId) async {
    if (!available) throw const PurchasesUnavailable();
    if (_configured) return logIn(appUserId);
    await Purchases.configure(
      PurchasesConfiguration(_key)..appUserID = appUserId,
    );
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
    _configured = true;
    _log.debug('configured');
  }

  @override
  Future<void> logIn(String appUserId) async {
    _ensureConfigured();
    await Purchases.logIn(appUserId);
  }

  @override
  Future<void> logOut() async {
    _ensureConfigured();
    try {
      await Purchases.logOut();
    } on PlatformException catch (e) {
      // Already signed out (anonymous) — nothing to do.
      if (PurchasesErrorHelper.getErrorCode(e) !=
          PurchasesErrorCode.logOutWithAnonymousUserError) {
        rethrow;
      }
    }
  }

  @override
  Future<PlusStatus> status() async {
    _ensureConfigured();
    return _statusOf(await Purchases.getCustomerInfo());
  }

  @override
  Future<PlusOffer?> offer() async {
    _ensureConfigured();
    final offerings = await Purchases.getOfferings();
    final package = offerings.current?.monthly;
    if (package == null) {
      _log.warn('offer: none');
      return null;
    }
    final product = package.storeProduct;
    return PlusOffer(
      priceString: product.priceString,
      trialDays: _isIos
          ? await _iosTrialDays(product)
          : _androidTrialDays(product),
      handle: package,
    );
  }

  /// The App Store intro offer, if it is free and this user is eligible.
  Future<int?> _iosTrialDays(StoreProduct product) async {
    final intro = product.introductoryPrice;
    if (intro == null || intro.price != 0) return null;
    try {
      final eligibility =
          await Purchases.checkTrialOrIntroductoryPriceEligibility([
            product.identifier,
          ]);
      if (eligibility[product.identifier]?.status !=
          IntroEligibilityStatus.introEligibilityStatusEligible) {
        return null;
      }
    } on PlatformException {
      _log.warn('offer: eligibility unknown');
      return null;
    }
    return trialDaysOf(
      intro.periodUnit,
      intro.periodNumberOfUnits * (intro.cycles < 1 ? 1 : intro.cycles),
    );
  }

  /// Google Play only hands out offers the user is eligible for, so a free
  /// phase on the default option means the trial applies.
  int? _androidTrialDays(StoreProduct product) {
    final free = product.defaultOption?.freePhase;
    final period = free?.billingPeriod;
    if (free == null || period == null) return null;
    final cycles = free.billingCycleCount ?? 1;
    return trialDaysOf(period.unit, period.value * (cycles < 1 ? 1 : cycles));
  }

  @override
  Future<PurchaseOutcome> purchase(PlusOffer offer) async {
    _ensureConfigured();
    final package = offer.handle;
    if (package is! Package) return const PurchaseFailed();
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      _log.debug('purchase: done');
      return PurchaseDone(_statusOf(result.customerInfo));
    } on PlatformException catch (e) {
      return _failure('purchase', e);
    }
  }

  @override
  Future<PurchaseOutcome> restore() async {
    _ensureConfigured();
    try {
      final info = await Purchases.restorePurchases();
      _log.debug('restore: done');
      return PurchaseDone(_statusOf(info));
    } on PlatformException catch (e) {
      return _failure('restore', e);
    }
  }

  PurchaseOutcome _failure(String what, PlatformException e) {
    final code = PurchasesErrorHelper.getErrorCode(e);
    switch (code) {
      case PurchasesErrorCode.purchaseCancelledError:
        _log.debug('$what: cancelled');
        return const PurchaseCancelled();
      case PurchasesErrorCode.paymentPendingError:
        _log.debug('$what: pending');
        return const PurchasePending();
      default:
        _log.warn('$what: failed (${code.name})');
        return const PurchaseFailed();
    }
  }

  /// Stops listening; the gateway is unusable afterwards.
  void dispose() {
    if (_configured) {
      Purchases.removeCustomerInfoUpdateListener(_onCustomerInfo);
    }
    _changes.close();
  }
}
