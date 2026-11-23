/// The ranges the registration offers for the body data, shared with
/// „Mein Profil" so both accept the same values.
abstract final class ProfileLimits {
  /// The youngest age the birth year picker offers.
  static const minAgeYears = 10;

  /// How many years the birth year picker offers.
  static const birthYearSpan = 100;

  static const minHeightCm = 120;
  static const maxHeightCm = 219;
  static const minWeightKg = 30;
  static const maxWeightKg = 179;

  /// The latest birth year on offer in [currentYear].
  static int maxBirthYear(int currentYear) => currentYear - minAgeYears;

  /// The earliest birth year on offer in [currentYear].
  static int minBirthYear(int currentYear) =>
      maxBirthYear(currentYear) - birthYearSpan + 1;

  /// The registration picker's birth years, latest first.
  static List<int> birthYears(int currentYear) => [
    for (var y = maxBirthYear(currentYear); y >= minBirthYear(currentYear); y--)
      y,
  ];

  static List<int> get heights => [
    for (var h = minHeightCm; h <= maxHeightCm; h++) h,
  ];

  static List<int> get weights => [
    for (var w = minWeightKg; w <= maxWeightKg; w++) w,
  ];

  /// [text] as a birth year: its value, or the German error to show.
  static ({int? value, String? error}) birthYear(
    String text, {
    required int currentYear,
  }) => _parse(
    text,
    min: minBirthYear(currentYear),
    max: maxBirthYear(currentYear),
    error: (min, max) =>
        'Bitte gib ein Geburtsjahr zwischen $min und $max ein.',
  );

  /// [text] as a height in cm: its value, or the German error to show.
  static ({int? value, String? error}) height(String text) => _parse(
    text,
    min: minHeightCm,
    max: maxHeightCm,
    error: (min, max) => 'Bitte gib eine Größe zwischen $min und $max cm ein.',
  );

  /// [text] as a weight in kg: its value, or the German error to show.
  static ({int? value, String? error}) weight(String text) => _parse(
    text,
    min: minWeightKg,
    max: maxWeightKg,
    error: (min, max) => 'Bitte gib ein Gewicht zwischen $min und $max kg ein.',
  );

  static ({int? value, String? error}) _parse(
    String text, {
    required int min,
    required int max,
    required String Function(int min, int max) error,
  }) {
    final value = int.tryParse(text.trim());
    if (value == null || value < min || value > max) {
      return (value: null, error: error(min, max));
    }
    return (value: value, error: null);
  }
}
