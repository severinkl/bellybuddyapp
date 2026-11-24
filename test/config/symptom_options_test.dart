import 'package:belly_buddy/config/symptom_options.dart';
import 'package:belly_buddy/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kSymptomOptions', () {
    test('values and labels are unique', () {
      final values = kSymptomOptions.map((s) => s.value).toList();
      final labels = kSymptomOptions.map((s) => s.label).toList();
      expect(values.toSet(), hasLength(values.length));
      expect(labels.toSet(), hasLength(labels.length));
    });

    test('the registration offers a subset of the same list', () {
      expect(kRegistrationSymptomOptions, isNotEmpty);
      for (final s in kRegistrationSymptomOptions) {
        expect(kSymptomOptions, contains(s));
      }
    });
  });

  group('normalizeSymptoms', () {
    test('maps the old registration labels to the canonical values', () {
      expect(
        normalizeSymptoms([
          'Belastender Durchfall',
          'Nervige Verstopfung',
          'Unangenehme Blähungen',
          'Übermäßiges Völlegefühl',
          'Hartnäckiger Blähbauch ohne Pupsen',
        ]),
        ['Durchfall', 'Verstopfung', 'Blähungen', 'Völlegefühl', 'Blähbauch'],
      );
    });

    test('keeps the old Mein Profil values, they are canonical', () {
      const short = [
        'Blähungen',
        'Bauchschmerzen',
        'Durchfall',
        'Verstopfung',
        'Übelkeit',
        'Sodbrennen',
        'Krämpfe',
        'Völlegefühl',
      ];
      expect(normalizeSymptoms(short), short);
    });

    test('a mix of both spellings collapses to one value each', () {
      expect(
        normalizeSymptoms(['Nervige Verstopfung', 'Verstopfung', 'Blähungen']),
        ['Verstopfung', 'Blähungen'],
      );
    });

    test('an unknown value is kept, not dropped', () {
      expect(normalizeSymptoms(['Kopfweh']), ['Kopfweh']);
    });
  });

  group('UserProfile.symptoms', () {
    test('reads stored registration labels as canonical values', () {
      final profile = UserProfile.fromJson({
        'symptoms': ['Nervige Verstopfung', 'Übermäßiges Völlegefühl'],
      });
      expect(profile.symptoms, ['Verstopfung', 'Völlegefühl']);
    });

    test('reads stored Mein Profil values unchanged', () {
      final profile = UserProfile.fromJson({
        'symptoms': ['Verstopfung', 'Krämpfe'],
      });
      expect(profile.symptoms, ['Verstopfung', 'Krämpfe']);
    });

    test('a missing column reads as no symptoms', () {
      expect(UserProfile.fromJson({}).symptoms, isEmpty);
      expect(UserProfile.fromJson({'symptoms': null}).symptoms, isEmpty);
    });

    test('writes canonical values', () {
      const profile = UserProfile(symptoms: ['Belastender Durchfall']);
      expect(profile.toJson()['symptoms'], ['Durchfall']);
    });
  });
}
