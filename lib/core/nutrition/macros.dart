/// Macro keys used by the app, with the nutrient codes the backend may send
/// for each (TACO imports use `energy_kcal`, `lipids`…; other sources vary).
const macroAliases = {
  'kcal': ['cal', 'energy_kcal', 'energy', 'calories'],
  'protein': ['protein', 'proteins', 'ptn'],
  'carbs': ['carbohydrate', 'carbohydrates', 'carbs', 'chocdf'],
  'fat': ['lipids', 'fat', 'total_fat', 'lip'],
  'fiber': ['dietary_fiber', 'fiber', 'fibra'],
};

/// First of [macro]'s aliases present in [byCode] (case-insensitive keys).
T? pickMacro<T>(Map<String, T> byCode, String macro) {
  final lower = {for (final e in byCode.entries) e.key.toLowerCase(): e.value};
  for (final alias in macroAliases[macro] ?? const <String>[]) {
    if (lower.containsKey(alias)) return lower[alias];
  }
  return null;
}
