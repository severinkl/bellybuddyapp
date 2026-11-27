import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../utils/logger.dart';

const _log = AppLogger('BarcodeScanner');

/// Why the camera could not start.
enum ScannerFailure { permissionDenied, other }

/// Builds the live scanner. [onBarcode] gets each detected EAN-13/EAN-8/UPC-A
/// raw value; [onFailure] once when the camera cannot start. [active] false
/// stops the camera.
typedef BarcodeScannerBuilder =
    Widget Function(
      BuildContext context, {
      required bool active,
      required ValueChanged<String> onBarcode,
      required ValueChanged<ScannerFailure> onFailure,
    });

/// The scanner the product sheet renders; widget tests replace it (no camera).
final barcodeScannerProvider = Provider<BarcodeScannerBuilder>(
  (ref) => mobileScannerBuilder,
);

/// The product barcode formats that are reported.
const scannableFormats = [
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upcA,
];

bool isScannableFormat(BarcodeFormat format) =>
    scannableFormats.contains(format);

/// Permission denied is its own failure (the sheet points to the settings);
/// everything else is "other".
ScannerFailure scannerFailureOf(MobileScannerErrorCode code) =>
    code == MobileScannerErrorCode.permissionDenied
    ? ScannerFailure.permissionDenied
    : ScannerFailure.other;

Widget mobileScannerBuilder(
  BuildContext context, {
  required bool active,
  required ValueChanged<String> onBarcode,
  required ValueChanged<ScannerFailure> onFailure,
}) => _MobileScannerView(
  active: active,
  onBarcode: onBarcode,
  onFailure: onFailure,
);

class _MobileScannerView extends StatefulWidget {
  const _MobileScannerView({
    required this.active,
    required this.onBarcode,
    required this.onFailure,
  });

  final bool active;
  final ValueChanged<String> onBarcode;
  final ValueChanged<ScannerFailure> onFailure;

  @override
  State<_MobileScannerView> createState() => _MobileScannerViewState();
}

class _MobileScannerViewState extends State<_MobileScannerView> {
  late final MobileScannerController _controller = MobileScannerController(
    formats: scannableFormats,
    autoStart: widget.active,
  );

  /// The failure was reported; the errorBuilder runs on every rebuild.
  bool _failureReported = false;

  @override
  void didUpdateWidget(_MobileScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _failureReported = false;
      _guard(_controller.start());
    } else {
      _guard(_controller.stop());
    }
  }

  /// Rapid toggling can make start/stop throw (initializing, disposed):
  /// log the error kind only, never anything scanned.
  void _guard(Future<void> future) => unawaited(
    future.catchError((Object e, StackTrace st) {
      _log.error(
        'Scanner start/stop failed: ${e is MobileScannerException ? e.errorCode.name : e.runtimeType}',
      );
    }),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!widget.active) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || !isScannableFormat(barcode.format)) continue;
      widget.onBarcode(value);
    }
  }

  Widget _error(BuildContext context, MobileScannerException error) {
    if (!_failureReported) {
      _failureReported = true;
      final failure = scannerFailureOf(error.errorCode);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFailure(failure);
      });
    }
    return const SizedBox.expand();
  }

  @override
  Widget build(BuildContext context) => MobileScanner(
    controller: _controller,
    onDetect: _onDetect,
    errorBuilder: _error,
  );
}
