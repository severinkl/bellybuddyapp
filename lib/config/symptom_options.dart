/// A symptom the user can name: in the registration and in Mein Profil.
class SymptomOption {
  const SymptomOption(
    this.value,
    this.label, {
    this.legacy = const [],
    this.inRegistration = false,
  });

  /// What `profiles.symptoms` stores.
  final String value;

  /// What the user sees.
  final String label;

  /// Older stored spellings of the same symptom (the first sign-up wrote its
  /// own long labels), read as [value].
  final List<String> legacy;

  /// Offered in the registration too (Mein Profil offers every symptom).
  final bool inRegistration;
}

/// The one symptom list. Registration and Mein Profil both pick from it, so
/// a symptom picked in one shows as picked in the other.
const List<SymptomOption> kSymptomOptions = [
  SymptomOption(
    'Durchfall',
    'Durchfall',
    legacy: ['Belastender Durchfall'],
    inRegistration: true,
  ),
  SymptomOption(
    'Verstopfung',
    'Verstopfung',
    legacy: ['Nervige Verstopfung'],
    inRegistration: true,
  ),
  SymptomOption(
    'Blähungen',
    'Blähungen',
    legacy: ['Unangenehme Blähungen'],
    inRegistration: true,
  ),
  SymptomOption(
    'Völlegefühl',
    'Völlegefühl',
    legacy: ['Übermäßiges Völlegefühl'],
    inRegistration: true,
  ),
  SymptomOption(
    'Blähbauch',
    'Blähbauch',
    legacy: ['Hartnäckiger Blähbauch ohne Pupsen'],
    inRegistration: true,
  ),
  SymptomOption('Bauchschmerzen', 'Bauchschmerzen'),
  SymptomOption('Krämpfe', 'Krämpfe'),
  SymptomOption('Übelkeit', 'Übelkeit'),
  SymptomOption('Sodbrennen', 'Sodbrennen'),
];

/// The symptoms the registration asks about.
final List<SymptomOption> kRegistrationSymptomOptions = [
  for (final s in kSymptomOptions)
    if (s.inRegistration) s,
];

final Map<String, String> _canonicalByStored = {
  for (final s in kSymptomOptions) ...{
    s.value: s.value,
    for (final l in s.legacy) l: s.value,
  },
};

/// [stored] symptoms as canonical values: every known spelling maps to its
/// value, duplicates collapse (first one wins), unknown values stay as they
/// are, so nothing the user once picked is lost.
List<String> normalizeSymptoms(Iterable<String> stored) {
  final out = <String>[];
  for (final s in stored) {
    final value = _canonicalByStored[s] ?? s;
    if (!out.contains(value)) out.add(value);
  }
  return out;
}

/// The label for a stored symptom [value] (the value itself when unknown).
String symptomLabel(String value) {
  for (final s in kSymptomOptions) {
    if (s.value == value) return s.label;
  }
  return value;
}
