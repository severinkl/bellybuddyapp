import 'package:material_ui/material_ui.dart';

/// A bottom sheet's own messenger, so its SnackBars (a failed save, a link
/// that did not open) show in the sheet: the page's messenger paints on a
/// Scaffold under the sheet and its scrim.
class BbSheetMessenger extends StatelessWidget {
  const BbSheetMessenger({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // The sheet keeps its height with the keyboard up.
        resizeToAvoidBottomInset: false,
        body: child,
      ),
    );
  }
}
