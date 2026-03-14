class ReplacementIngredient {
  final String id;
  final String name;
  final String? imageUrl;

  const ReplacementIngredient({
    required this.id,
    required this.name,
    this.imageUrl,
  });
}
