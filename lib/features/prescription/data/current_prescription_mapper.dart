import '../domain/current_prescription.dart';

/// Converte o JSON de `PrescriptionOutput.VersionOutput` do servidor.
/// Lança [FormatException] se faltar um campo obrigatório.
CurrentPrescription currentPrescriptionFromJson(Map<String, dynamic> json) {
  final meals = [for (final raw in _list(json['meals'])) _mealFrom(_map(raw))]
    ..sort((a, b) => a.order.compareTo(b.order));
  return CurrentPrescription(
    id: _string(json, 'id'),
    number: _int(json, 'number'),
    title: _optString(json['title']),
    notes: _optString(json['notes']),
    createdByUserId: _optString(json['createdByUserId']),
    publishedAt: DateTime.tryParse('${json['publishedAt'] ?? ''}'),
    planningMode: PlanningMode.fromCode(json['planningMode']),
    meals: meals,
    targets: _targetsFrom(_list(json['nutritionTargets'])),
  );
}

PrescribedMeal _mealFrom(Map<String, dynamic> json) {
  final items = [for (final raw in _list(json['items'])) _itemFrom(_map(raw))]
    ..sort((a, b) => a.order.compareTo(b.order));
  return PrescribedMeal(
    id: _string(json, 'id'),
    name: _string(json, 'name'),
    mealType: _string(json, 'mealType'),
    order: _int(json, 'order'),
    suggestedTime: _time(json['suggestedTime']),
    notes: _optString(json['notes']),
    items: items,
  );
}

PrescribedItem _itemFrom(Map<String, dynamic> json) => PrescribedItem(
  id: _string(json, 'id'),
  foodId: _string(json, 'foodId'),
  foodPortionId: _optString(json['foodPortionId']),
  quantity: _decimal(json, 'quantity'),
  unit: _string(json, 'unit'),
  order: _int(json, 'order'),
  notes: _optString(json['notes']),
  substitutions: [
    for (final raw in _list(json['substitutions']))
      _substitutionFrom(_map(raw)),
  ],
);

AllowedSubstitution _substitutionFrom(Map<String, dynamic> json) =>
    AllowedSubstitution(
      id: _string(json, 'id'),
      foodId: _string(json, 'foodId'),
      foodPortionId: _optString(json['foodPortionId']),
      quantity: _decimal(json, 'quantity'),
      unit: _string(json, 'unit'),
      notes: _optString(json['notes']),
    );

NutritionTargets _targetsFrom(List<dynamic> raw) {
  final byCode = <String, String>{};
  for (final entry in raw) {
    final map = _map(entry);
    final code = map['nutrientCode'];
    final amount = map['amount'];
    if (code is String && amount != null) byCode[code] = '$amount';
  }
  return NutritionTargets(
    energyKcal: byCode['energy_kcal'],
    protein: byCode['protein'],
    carbohydrate: byCode['carbohydrate'],
    lipids: byCode['lipids'],
  );
}

Map<String, dynamic> _map(Object? value) => value is Map<String, dynamic>
    ? value
    : throw const FormatException('Objeto esperado.');

List<dynamic> _list(Object? value) => value is List ? value : const [];

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String && value.isNotEmpty
      ? value
      : throw FormatException('Campo "$key" ausente.');
}

String? _optString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is int ? value : throw FormatException('Campo "$key" ausente.');
}

String _decimal(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is num || (value is String && num.tryParse(value) != null)
      ? '$value'
      : throw FormatException('Campo "$key" ausente.');
}

/// `LocalTime` chega como `HH:mm` ou `HH:mm:ss`; mantém `HH:mm`.
String? _time(Object? value) {
  if (value is! String) return null;
  final match = RegExp(r'^(\d{2}):(\d{2})').firstMatch(value);
  return match == null ? null : '${match.group(1)}:${match.group(2)}';
}
