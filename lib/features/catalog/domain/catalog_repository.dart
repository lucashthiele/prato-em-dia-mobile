class CatalogFailure implements Exception {
  const CatalogFailure(this.message, {this.notFound = false});

  final String message;
  final bool notFound;
}

class FoodSummary {
  const FoodSummary({
    required this.id,
    required this.name,
    required this.origin,
    this.brand,
    this.category,
    this.source,
  });

  final String id;
  final String name;
  final String origin;
  final String? brand;
  final String? category;
  final String? source;
}

class Nutrient {
  const Nutrient({
    required this.status,
    required this.unit,
    this.amount,
    this.rawValue,
  });

  final String status;
  final String unit;
  final String? amount;
  final String? rawValue;
}

class FoodPortion {
  const FoodPortion({
    required this.id,
    required this.label,
    required this.nutrients,
    this.quantity,
    this.unit,
    this.gramsEquivalent,
  });

  final String id;
  final String label;
  final String? quantity;
  final String? unit;
  final String? gramsEquivalent;
  final Map<String, Nutrient> nutrients;
}

class FoodDetails {
  const FoodDetails({
    required this.food,
    required this.portions,
    this.notes,
    this.preparationMethod,
  });

  final FoodSummary food;
  final String? notes;
  final String? preparationMethod;
  final List<FoodPortion> portions;
}

class CatalogPage {
  const CatalogPage({required this.foods, required this.totalPages});

  final List<FoodSummary> foods;
  final int totalPages;
}

abstract interface class CatalogRepository {
  Future<CatalogPage> list(int page);
  Future<FoodDetails> get(String id);
}
