import 'package:flutter_test/flutter_test.dart';
import 'package:belly_buddy/utils/password_validator.dart';

void main() {
  group('PasswordValidator.validate', () {
    test('short password fails hasMinLength', () {
      final v = PasswordValidator.validate('Abc1');
      expect(v.hasMinLength, false);
    });

    test('no uppercase fails hasUppercase', () {
      final v = PasswordValidator.validate('abcdefg1');
      expect(v.hasUppercase, false);
    });

    test('no lowercase fails hasLowercase', () {
      final v = PasswordValidator.validate('ABCDEFG1');
      expect(v.hasLowercase, false);
    });

    test('no number fails hasNumber', () {
      final v = PasswordValidator.validate('Abcdefgh');
      expect(v.hasNumber, false);
    });

    test('valid password passes all', () {
      final v = PasswordValidator.validate('Abcdefg1');
      expect(v.hasMinLength, true);
      expect(v.hasUppercase, true);
      expect(v.hasLowercase, true);
      expect(v.hasNumber, true);
    });

    test('allMet true only when all 4 pass', () {
      expect(PasswordValidator.validate('Abcdefg1').allMet, true);
      expect(PasswordValidator.validate('abcdefg1').allMet, false);
      expect(PasswordValidator.validate('Ab1').allMet, false);
    });

    test('empty password fails all', () {
      final v = PasswordValidator.validate('');
      expect(v.allMet, false);
      expect(v.hasMinLength, false);
      expect(v.hasUppercase, false);
      expect(v.hasLowercase, false);
      expect(v.hasNumber, false);
    });
  });

  group('PasswordValidator.canSubmit', () {
    test('returns false when current password empty', () {
      expect(
        PasswordValidator.canSubmit(
          currentPassword: '',
          newPassword: 'Abcdefg1',
          confirmPassword: 'Abcdefg1',
        ),
        false,
      );
    });

    test('returns false when passwords dont match', () {
      expect(
        PasswordValidator.canSubmit(
          currentPassword: 'old',
          newPassword: 'Abcdefg1',
          confirmPassword: 'Abcdefg2',
        ),
        false,
      );
    });

    test('returns false when new password fails validation', () {
      expect(
        PasswordValidator.canSubmit(
          currentPassword: 'old',
          newPassword: 'short',
          confirmPassword: 'short',
        ),
        false,
      );
    });

    test('returns true when all conditions met', () {
      expect(
        PasswordValidator.canSubmit(
          currentPassword: 'oldpassword',
          newPassword: 'Abcdefg1',
          confirmPassword: 'Abcdefg1',
        ),
        true,
      );
    });
  });
}
