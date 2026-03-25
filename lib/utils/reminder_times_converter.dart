import 'package:freezed_annotation/freezed_annotation.dart';

class ReminderTimesConverter
    implements JsonConverter<List<String>, List<dynamic>> {
  const ReminderTimesConverter();

  @override
  List<String> fromJson(List<dynamic> json) {
    return json.map((e) {
      if (e is String) return e;
      if (e is int) return '${e.toString().padLeft(2, '0')}:00';
      return e.toString();
    }).toList();
  }

  @override
  List<dynamic> toJson(List<String> object) => object;
}
