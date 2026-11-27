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
}
