class PasswordValidation {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;

  const PasswordValidation({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
  });

  bool get allMet => hasMinLength && hasUppercase && hasLowercase && hasNumber;
}

abstract final class PasswordValidator {
  static final _uppercase = RegExp(r'[A-Z]');
  static final _lowercase = RegExp(r'[a-z]');
  static final _number = RegExp(r'[0-9]');

  static PasswordValidation validate(String password) {
    return PasswordValidation(
      hasMinLength: password.length >= 8,
      hasUppercase: password.contains(_uppercase),
      hasLowercase: password.contains(_lowercase),
      hasNumber: password.contains(_number),
    );
  }

  static bool canSubmit({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    final v = validate(newPassword);
    return v.allMet &&
        newPassword.isNotEmpty &&
        newPassword == confirmPassword &&
        currentPassword.isNotEmpty;
  }
}
