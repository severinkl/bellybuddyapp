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

  /// Names the button for assistive tech in place of [label] (when the
  /// visible text needs its context, e.g. „Wasser, 250 ml eintragen" for
  /// „Eintragen"); the visible text stays [label].
  final String? semanticLabel;

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
    this.semanticLabel,
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

    final lead = icon == null
        ? leading
        : Icon(icon, size: AppConstants.iconSizeClose);
    final spoken = semanticLabel;
    final Widget child = isLoading
        // The label stays in semantics while the spinner shows. It merges
        // into the button's own node, which is already a disabled button
        // (repeating those flags here would split it into a second node).
        ? Semantics(
            label: spoken ?? label,
            value: 'lädt',
            child: const ExcludeSemantics(
              child: SizedBox(
                width: AppConstants.iconSizeMd,
                height: AppConstants.iconSizeMd,
                child: CircularProgressIndicator(
                  strokeWidth: AppConstants.borderWidthLg,
                ),
              ),
            ),
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
    // The spoken name merges into the button's node like the text would.
    final named = spoken == null || isLoading
        ? child
        : Semantics(
            label: spoken,
            child: ExcludeSemantics(child: child),
          );

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
        child: named,
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
      child: named,
    );
  }
}
