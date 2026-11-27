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

/// Whether the view may (re)start the camera when it becomes active. Not
/// after a failure was reported, not while a start is still running, and —
/// as mobile_scanner's own lifecycle handler — not once the controller
/// knows the permission is missing: on Android every start asks for the
/// permission again.
bool mayStartScanner(
  MobileScannerState state, {
  required bool failureReported,
}) {
  if (failureReported || state.isStarting) return false;
  return !state.isInitialized || state.hasCameraPermission;
}

/// Whether the view must stop a camera that runs although the view is
/// inactive: mobile_scanner ignores a stop while a start is still pending,
/// so the view stops it once that start completes.
bool mustStopScanner(MobileScannerState state, {required bool active}) =>
    !active && state.isRunning;

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

  /// The failure was reported; the errorBuilder runs on every rebuild. It
  /// stays for this view: the sheet mounts a new one to try again.
  bool _failureReported = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerValue);
  }

  /// A start that completes after [_MobileScannerView.active] turned false
  /// leaves the camera running: stop it then.
  void _onControllerValue() {
    if (mustStopScanner(_controller.value, active: widget.active)) {
      _guard(_controller.stop());
    }
  }

  @override
  void didUpdateWidget(_MobileScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      if (mayStartScanner(
        _controller.value,
        failureReported: _failureReported,
      )) {
        _guard(_controller.start());
      }
    } else {
      // A no-op while a start is pending: [_onControllerValue] stops it.
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
    _controller.removeListener(_onControllerValue);
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
