/// One ingredient of a looked-up product; [ingredientId] is set when core
/// matched it to the shared catalogue.
class ProductIngredient {
  const ProductIngredient({required this.name, this.ingredientId});

  final String name;
  final String? ingredientId;
}

/// A product as the meal tracker prefills it.
class ProductPrefill {
  const ProductPrefill({
    required this.barcode,
    required this.title,
    this.brand,
    required this.ingredients,
  });

  final String barcode;
  final String title;
  final String? brand;
  final List<ProductIngredient> ingredients;
}

/// One search result.
class ProductHit {
  const ProductHit({required this.barcode, required this.name, this.brand});

  final String barcode;
  final String name;
  final String? brand;
}

sealed class ProductLookup {}

final class ProductFound extends ProductLookup {
  ProductFound(this.product);

  final ProductPrefill product;
}

final class ProductNotFound extends ProductLookup {
  ProductNotFound(this.barcode);

  final String barcode;
}
