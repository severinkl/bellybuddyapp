import 'package:material_ui/material_ui.dart';
import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../services/haptic_service.dart';

class BbButton extends StatelessWidget {
  final Key? tapKey;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool isDestructive;
  final bool isSecondary;
  final IconData? icon;

  /// Drawn before the label in place of an [icon] (a sticker icon).
  final Widget? leading;

  const BbButton({
    super.key,
    required this.label,
    this.tapKey,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.isDestructive = false,
    this.isSecondary = false,
    this.icon,
    this.leading,
  }) : assert(
         icon == null || leading == null,
         'An icon or a leading widget, not both',
       );

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading
        ? null
        : onPressed != null
        ? () {
            HapticService.light();
            onPressed!();
          }
        : null;

    final lead = icon == null ? leading : Icon(icon, size: 20);
    final child = isLoading
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : lead != null
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              lead,
              const SizedBox(width: AppConstants.spacingSm),
              // A long label wraps instead of overflowing the button.
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          )
        : Text(label);

    if (isOutlined) {
      return OutlinedButton(
        key: tapKey,
        onPressed: effectiveOnPressed,
        style: isDestructive
            ? OutlinedButton.styleFrom(
                foregroundColor: AppTheme.destructive,
                side: const BorderSide(color: AppTheme.destructive),
              )
            : null,
        child: child,
      );
    }

    return ElevatedButton(
      key: tapKey,
      onPressed: effectiveOnPressed,
      style: isDestructive
          ? ElevatedButton.styleFrom(
              backgroundColor: AppTheme.destructive,
              foregroundColor: Colors.white,
            )
          : isSecondary
          ? ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              foregroundColor: AppTheme.secondaryForeground,
            )
          : null,
      child: child,
    );
  }
}
