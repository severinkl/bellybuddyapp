import 'package:flutter_test/flutter_test.dart';

import 'package:belly_buddy/utils/profile_limits.dart';

void main() {
  test('the registration ranges: 100 birth years from age 10, 120-219 cm, '
      '30-179 kg', () {
    final years = ProfileLimits.birthYears(2026);
    expect(years.first, 2016);
    expect(years.last, 1917);
    expect(years, hasLength(100));
    expect(ProfileLimits.heights.first, 120);
    expect(ProfileLimits.heights.last, 219);
    expect(ProfileLimits.weights.first, 30);
    expect(ProfileLimits.weights.last, 179);
  });

  test('parses values in range, explains the rest', () {
    expect(ProfileLimits.birthYear('1990', currentYear: 2026).value, 1990);
    expect(ProfileLimits.birthYear('2016', currentYear: 2026).value, 2016);
    final tooYoung = ProfileLimits.birthYear('2024', currentYear: 2026);
    expect(tooYoung.value, isNull);
    expect(
      tooYoung.error,
      'Bitte gib ein Geburtsjahr zwischen 1917 und 2016 ein.',
    );
    expect(ProfileLimits.birthYear('', currentYear: 2026).value, isNull);

    expect(ProfileLimits.height('219').value, 219);
    expect(ProfileLimits.height('220').error, isNotNull);
    expect(ProfileLimits.weight('29').error, isNotNull);
    expect(ProfileLimits.weight(' 64 ').value, 64);
  });
}
