import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../config/app_theme.dart';
import '../../../config/constants.dart';
import '../../../utils/practice_code.dart';

/// Opens the scanner; the practice code it read, or null when closed.
typedef PracticeCodeScan = Future<String?> Function(BuildContext context);

/// The camera view: calls `onScan` with the raw values of each detection.
typedef ScannerCamera =
    Widget Function(BuildContext context, ValueChanged<List<String?>> onScan);

/// How the connect screen scans; tests replace it (no camera there).
final practiceCodeScanProvider = Provider<PracticeCodeScan>(
  (ref) =>
      (context) => Navigator.of(context).push<String>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const PracticeCodeScanner(),
        ),
      ),
);

/// The view shown instead of the camera when it cannot run (no permission,
/// no camera).
Widget scannerErrorView(BuildContext context, MobileScannerException error) =>
    const Center(
      child: Padding(
        padding: AppConstants.paddingLg,
        child: Text(
          'Ohne Kamera kannst du den Code auch eintippen.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTheme.fontSizeBodyLG,
            color: Colors.white,
            height: AppTheme.lineHeightBody,
          ),
        ),
      ),
    );

Widget _mobileScanner(
  BuildContext context,
  ValueChanged<List<String?>> onScan,
) => MobileScanner(
  onDetect: (capture) =>
      onScan([for (final barcode in capture.barcodes) barcode.rawValue]),
  errorBuilder: scannerErrorView,
);

/// A full-screen QR scanner that pops with the first practice code
/// [practiceCodeFromScan] accepts. A QR code it rejects shows
/// [rejectedLine] and the scanner keeps running. Nothing scanned is logged.
class PracticeCodeScanner extends StatefulWidget {
  const PracticeCodeScanner({super.key, this.camera = _mobileScanner});

  static const rejectedLine = 'Das ist kein Praxis-Code.';

  final ScannerCamera camera;

  @override
  State<PracticeCodeScanner> createState() => _PracticeCodeScannerState();
}

class _PracticeCodeScannerState extends State<PracticeCodeScanner> {
  /// A code was taken: later detections while popping are dropped.
  bool _done = false;

  /// A QR code was read that is no practice code.
  bool _rejected = false;

  void _onScan(List<String?> values) {
    if (_done || !mounted) return;
    for (final raw in values) {
      final code = raw == null ? null : practiceCodeFromScan(raw);
      if (code == null) continue;
      _done = true;
      Navigator.of(context).pop(code);
      return;
    }
    if (!_rejected && values.any((raw) => raw != null)) {
      setState(() => _rejected = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('QR-Code scannen'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          widget.camera(context, _onScan),
          if (_rejected)
            const Positioned(
              left: AppConstants.spacingMd,
              right: AppConstants.spacingMd,
              bottom: AppConstants.spacingLg,
              // On the scrim: white text stays readable over any picture.
              child: SafeArea(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.scrim,
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppConstants.radiusMd),
                    ),
                  ),
                  child: Padding(
                    padding: AppConstants.paddingSm,
                    child: Text(
                      PracticeCodeScanner.rejectedLine,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeBodyLG,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
