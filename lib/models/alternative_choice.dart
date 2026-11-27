enum AlternativeChoiceKind {
  tryIt('try'),
  skip('skip');

  const AlternativeChoiceKind(this.db);

  /// The value of the `choice` column.
  final String db;

  static AlternativeChoiceKind fromDb(String value) =>
      values.firstWhere((k) => k.db == value);
}

/// A user's choice on an alternative ingredient: „Probiere ich" or „Passt
/// nicht für mich" (core table `alternative_choices`).
class AlternativeChoice {
  const AlternativeChoice({
    required this.id,
    required this.ingredientId,
    required this.ingredientName,
    required this.replacementId,
    required this.replacementName,
    required this.kind,
    required this.createdAt,
  });

  final String id;
  final String ingredientId;
  final String ingredientName;
  final String replacementId;
  final String replacementName;
  final AlternativeChoiceKind kind;
  final DateTime createdAt;

  /// A row of the service: the ingredient names come from the `ingredient`
  /// and `replacement` embeds.
  factory AlternativeChoice.fromRow(Map<String, dynamic> row) =>
      AlternativeChoice(
        id: row['id'] as String,
        ingredientId: row['ingredient_id'] as String,
        ingredientName:
            (row['ingredient'] as Map<String, dynamic>)['name'] as String,
        replacementId: row['replacement_ingredient_id'] as String,
        replacementName:
            (row['replacement'] as Map<String, dynamic>)['name'] as String,
        kind: AlternativeChoiceKind.fromDb(row['choice'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}
