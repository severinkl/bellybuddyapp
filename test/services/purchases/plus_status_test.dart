import 'package:belly_buddy/models/plus_status.dart';
import 'package:belly_buddy/services/purchases/revenuecat_gateway.dart';
import 'package:belly_buddy/services/purchases/purchases_gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

EntitlementInfo _plus({
  bool isActive = true,
  bool willRenew = true,
  PeriodType periodType = PeriodType.normal,
  String? expirationDate = '2026-12-27T10:00:00Z',
  String? billingIssueDetectedAt,
}) => EntitlementInfo(
  'plus',
  isActive,
  willRenew,
  '2026-11-27T10:00:00Z',
  '2026-11-27T10:00:00Z',
  'bb_plus_monthly',
  true,
  periodType: periodType,
  expirationDate: expirationDate,
  billingIssueDetectedAt: billingIssueDetectedAt,
);

void main() {
  group('plusStatusOf', () {
    test('no entitlement → none', () {
      final status = plusStatusOf(null);
      expect(status.state, PlusState.none);
      expect(status.granted, isFalse);
      expect(status.expiresAt, isNull);
    });

    test('active in the trial period → trial', () {
      final status = plusStatusOf(_plus(periodType: PeriodType.trial));
      expect(status.state, PlusState.trial);
      expect(status.granted, isTrue);
    });

    test('active, normal period → active with expiry and renewal copied', () {
      final status = plusStatusOf(
        _plus(willRenew: false),
        managementUrl: 'https://apps.apple.com/account/subscriptions',
      );
      expect(status.state, PlusState.active);
      expect(status.granted, isTrue);
      expect(status.willRenew, isFalse);
      expect(status.expiresAt, DateTime.utc(2026, 12, 27, 10));
      expect(status.billingIssue, isFalse);
      expect(
        status.managementUrl,
        'https://apps.apple.com/account/subscriptions',
      );
    });

    test('active with renewal on → willRenew', () {
      expect(plusStatusOf(_plus()).willRenew, isTrue);
    });

    test('active without expiry (lifetime) → active, no date', () {
      final status = plusStatusOf(_plus(expirationDate: null));
      expect(status.state, PlusState.active);
      expect(status.expiresAt, isNull);
    });

    test('present but inactive → lapsed', () {
      final status = plusStatusOf(
        _plus(isActive: false, periodType: PeriodType.trial, willRenew: false),
      );
      expect(status.state, PlusState.lapsed);
      expect(status.granted, isFalse);
    });

    test('billingIssueDetectedAt set → billingIssue', () {
      final status = plusStatusOf(
        _plus(billingIssueDetectedAt: '2026-11-26T08:00:00Z'),
      );
      expect(status.billingIssue, isTrue);
      expect(status.state, PlusState.active);
    });

    test('unparseable expiry → no date, state unaffected', () {
      final status = plusStatusOf(_plus(expirationDate: 'garbage'));
      expect(status.state, PlusState.active);
      expect(status.expiresAt, isNull);
    });
  });

  group('trialDaysOf', () {
    test('converts store periods into days', () {
      expect(trialDaysOf(PeriodUnit.day, 14), 14);
      expect(trialDaysOf(PeriodUnit.week, 2), 14);
      expect(trialDaysOf(PeriodUnit.month, 1), 30);
      expect(trialDaysOf(PeriodUnit.year, 1), 365);
    });

    test('unknown unit or non-positive length → null', () {
      expect(trialDaysOf(PeriodUnit.unknown, 14), isNull);
      expect(trialDaysOf(PeriodUnit.day, 0), isNull);
    });
  });

  group('RevenueCatGateway', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('available only with the key of the running platform', () {
      final onlyIos = RevenueCatGateway(iosKey: 'appl_x', androidKey: '');
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(onlyIos.available, isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(onlyIos.available, isFalse);
      expect(
        RevenueCatGateway(iosKey: '', androidKey: 'goog_x').available,
        isTrue,
      );
    });

    test('without a key configure refuses and nothing else runs', () async {
      final gateway = RevenueCatGateway(iosKey: '', androidKey: '');
      await expectLater(
        gateway.configure('u1'),
        throwsA(isA<PurchasesUnavailable>()),
      );
      await expectLater(gateway.status(), throwsA(isA<PurchasesUnavailable>()));
      await expectLater(gateway.offer(), throwsA(isA<PurchasesUnavailable>()));
      await expectLater(
        gateway.restore(),
        throwsA(isA<PurchasesUnavailable>()),
      );
      gateway.dispose();
    });
  });
}
