import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:belly_buddy/widgets/scanner/barcode_scanner.dart';

void main() {
  test('barcodeScannerProvider defaults to the mobile_scanner builder', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(barcodeScannerProvider), same(mobileScannerBuilder));
  });

  group('scannerFailureOf', () {
    test('permissionDenied maps to permissionDenied', () {
      expect(
        scannerFailureOf(MobileScannerErrorCode.permissionDenied),
        ScannerFailure.permissionDenied,
      );
    });

    test('every other code maps to other', () {
      for (final code in MobileScannerErrorCode.values) {
        if (code == MobileScannerErrorCode.permissionDenied) continue;
        expect(scannerFailureOf(code), ScannerFailure.other, reason: '$code');
      }
    });
  });

  group('isScannableFormat', () {
    test('accepts EAN-13, EAN-8 and UPC-A only', () {
      expect(isScannableFormat(BarcodeFormat.ean13), isTrue);
      expect(isScannableFormat(BarcodeFormat.ean8), isTrue);
      expect(isScannableFormat(BarcodeFormat.upcA), isTrue);
      expect(isScannableFormat(BarcodeFormat.qrCode), isFalse);
      expect(isScannableFormat(BarcodeFormat.code128), isFalse);
    });
  });

  group('mayStartScanner', () {
    const fresh = MobileScannerState.uninitialized();
    final running = fresh.copyWith(isInitialized: true, isRunning: true);
    final denied = fresh.copyWith(
      isInitialized: true,
      error: const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      ),
    );
    final otherError = fresh.copyWith(
      isInitialized: true,
      error: const MobileScannerException(
        errorCode: MobileScannerErrorCode.genericError,
      ),
    );

    test('starts a fresh controller and one with the permission', () {
      expect(mayStartScanner(fresh, failureReported: false), isTrue);
      expect(mayStartScanner(running, failureReported: false), isTrue);
    });

    test('never restarts once the permission was denied (Android would '
        'ask again)', () {
      expect(mayStartScanner(denied, failureReported: false), isFalse);
      expect(mayStartScanner(denied, failureReported: true), isFalse);
    });

    test('not after a reported failure', () {
      expect(mayStartScanner(fresh, failureReported: true), isFalse);
      expect(mayStartScanner(otherError, failureReported: true), isFalse);
    });

    test('not while a start (the permission dialog) is still running', () {
      expect(
        mayStartScanner(
          fresh.copyWith(isStarting: true),
          failureReported: false,
        ),
        isFalse,
      );
    });
  });
}
