import '../domain/catalog_repository.dart';

String originLabel(String origin, String? source) => switch (origin) {
  'IMPORTED' => source == null ? 'Importado' : 'Importado · Fonte: $source',
  'ADMIN' => 'Catálogo do aplicativo',
  'NUTRITIONIST' => 'Nutricionista',
  'PATIENT' => 'Paciente',
  _ => 'Outra origem',
};

String nutrientLabel(String key) => switch (key.toLowerCase()) {
  'energy' || 'energy_kcal' || 'calories' => 'Energia',
  'protein' || 'proteins' => 'Proteínas',
  'carbohydrate' || 'carbohydrates' || 'carbs' => 'Carboidratos',
  'fat' || 'total_fat' || 'lipids' => 'Gorduras totais',
  'saturated_fat' => 'Gorduras saturadas',
  'fiber' || 'dietary_fiber' => 'Fibras',
  'sodium' => 'Sódio',
  'sugar' || 'sugars' => 'Açúcares',
  _ => key,
};

String nutrientValueLabel(Nutrient nutrient) {
  if (nutrient.amount != null) {
    return '${nutrient.amount}${nutrient.unit.isEmpty ? '' : ' ${nutrient.unit}'}';
  }
  return switch (nutrient.status.toUpperCase()) {
    'TRACE' => 'traço',
    'NOT_AVAILABLE' || 'UNKNOWN' || 'NOT_INFORMED' => 'não disponível',
    'NOT_APPLICABLE' => 'não se aplica',
    'NOT_ANALYZED' => 'não analisado',
    _ =>
      nutrient.rawValue?.trim().isNotEmpty == true
          ? nutrient.rawValue!
          : 'não disponível',
  };
}
