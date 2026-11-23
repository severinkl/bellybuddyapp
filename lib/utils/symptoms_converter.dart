import 'package:freezed_annotation/freezed_annotation.dart';

import '../config/symptom_options.dart';

/// Reads and writes `profiles.symptoms` as canonical values (see
/// [kSymptomOptions]): older stored spellings come in as today's values, and
/// only those go back out.
class SymptomsConverter implements JsonConverter<List<String>, List<dynamic>> {
  const SymptomsConverter();

  @override
  List<String> fromJson(List<dynamic> json) =>
      normalizeSymptoms(json.map((e) => e.toString()));

  @override
  List<dynamic> toJson(List<String> object) => normalizeSymptoms(object);
}
