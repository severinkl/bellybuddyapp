enum DiaryEntryType { meal, toilet, gutFeeling, drink }

class DiaryEntry {
  final String id;
  final DiaryEntryType type;
  final DateTime trackedAt;
  final String title;
  final String subtitle;
  final Object? data;

  const DiaryEntry({
    required this.id,
    required this.type,
    required this.trackedAt,
    required this.title,
    required this.subtitle,
    this.data,
  });
}
