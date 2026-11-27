import 'package:material_ui/material_ui.dart';
import '../../config/app_theme.dart';

class BbPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  static const passwordFieldKey = Key('password_field');

  /// What a password field's eye says it does while the password is
  /// [obscured] or shown (every password field in the app).
  static String eyeTooltip(bool obscured) =>
      obscured ? 'Passwort anzeigen' : 'Passwort verbergen';

  const BbPasswordField({
    super.key,
    required this.controller,
    this.labelText = 'Passwort',
    this.validator,
    this.onChanged,
  });

  @override
  State<BbPasswordField> createState() => _BbPasswordFieldState();
}

class _BbPasswordFieldState extends State<BbPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: BbPasswordField.passwordFieldKey,
      controller: widget.controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: widget.labelText,
        suffixIcon: IconButton(
          tooltip: BbPasswordField.eyeTooltip(_obscure),
          icon: Icon(
            _obscure ? Icons.visibility_off : Icons.visibility,
            color: AppTheme.mutedForeground,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      onChanged: widget.onChanged,
      validator: widget.validator,
    );
  }
}
