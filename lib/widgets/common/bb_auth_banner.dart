import 'package:material_ui/material_ui.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';

class BbAuthBanner extends StatelessWidget {
  final String text;
  final bool isError;
  final Key? loginMessageKey;

  const BbAuthBanner({
    super.key,
    required this.text,
    this.isError = true,
    this.loginMessageKey,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppTheme.destructive : AppTheme.successText;
    // A live region, so a new message is read out without moving focus.
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacing12),
        margin: const EdgeInsets.only(bottom: AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        child: Text(
          key: loginMessageKey,
          text,
          style: TextStyle(color: color, fontSize: AppTheme.fontSizeBody),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
