import 'package:material_ui/material_ui.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';

/// A line of text over the camera picture: white on the scrim, so it stays
/// readable over any picture.
class ScannerScrimLabel extends StatelessWidget {
  const ScannerScrimLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppTheme.scrim,
      borderRadius: BorderRadius.all(Radius.circular(AppConstants.radiusMd)),
    ),
    child: Padding(
      padding: AppConstants.paddingSm,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeBody,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    ),
  );
}
