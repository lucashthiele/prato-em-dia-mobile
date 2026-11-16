import 'package:dio/dio.dart';

import '../../../core/network/api_error_messages.dart';
import '../../../core/network/api_failure.dart';
import '../domain/weekly_plan.dart';
import '../domain/weekly_planning_repository.dart';
import 'weekly_planning_api.dart';

class WeeklyPlanningRepositoryImpl implements WeeklyPlanningRepository {
  const WeeklyPlanningRepositoryImpl(this._api);

  final WeeklyPlanningRemoteDataSource _api;

  @override
  Future<List<WeeklyPlan>> list() => _run(
    () async =>
        (await _api.list()).map((value) => _plan(_object(value))).toList(),
  );

  @override
  Future<WeeklyPlan> get(String planId) =>
      _run(() async => _plan(await _api.get(planId)));

  @override
  Future<WeeklyPlan> generate() =>
      _run(() async => _plan(await _api.generate()));

  @override
  Future<WeeklyPlan> confirm(String planId) =>
      _run(() async => _plan(await _api.confirm(planId)));

  @override
  Future<WeeklyPlan> update(String planId, Map<String, dynamic> body) =>
      _run(() async => _plan(await _api.update(planId, body)));

  @override
  Future<void> delete(String planId) => _run(() => _api.delete(planId));

  @override
  Future<WeeklyPlanningPreference> getPreference() =>
      _run(() async => _preference(await _api.getPreference()));

  @override
  Future<WeeklyPlanningPreference> updatePreference(
    WeeklyPlanningPreference value,
  ) => _run(
    () async => _preference(
      await _api.updatePreference(
        dayOfWeek: value.dayOfWeek,
        enabled: value.enabled,
      ),
    ),
  );

  Future<T> _run<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      final failure = ApiFailure.fromDioException(error);
      throw PlanningFailure(
        ApiErrorMessages.of(failure),
        status: failure.status,
        code: failure.code,
      );
    } on FormatException {
      throw const PlanningFailure(
        'Não foi possível ler o planejamento. Tente novamente.',
      );
    } on TypeError {
      throw const PlanningFailure(
        'Não foi possível ler o planejamento. Tente novamente.',
      );
    }
  }

  static Map<String, dynamic> _object(Object? value) =>
      value is Map<String, dynamic>
      ? value
      : throw const FormatException('Formato inválido.');

  static String _string(Object? value) =>
      value is String ? value : throw const FormatException('Campo ausente.');

  static int _integer(Object? value) =>
      value is int ? value : throw const FormatException('Número inválido.');

  static String _decimal(Object? value) => value is num || value is String
      ? value.toString()
      : throw const FormatException('Quantidade inválida.');

  static List<dynamic> _array(Object? value) => value is List<dynamic>
      ? value
      : throw const FormatException('Lista inválida.');

  static WeeklyPlan _plan(Map<String, dynamic> json) => WeeklyPlan(
    id: _string(json['id']),
    prescriptionVersionId: _string(json['prescriptionVersionId']),
    planningMode: _string(json['planningMode']),
    periodStart: DateTime.parse(_string(json['periodStart'])),
    periodEnd: DateTime.parse(_string(json['periodEnd'])),
    confirmationDeadline: DateTime.parse(_string(json['confirmationDeadline'])),
    status: _string(json['status']),
    version: _integer(json['version']),
    meals: _array(json['meals']).map((value) {
      final meal = _object(value);
      return PlannedMeal(
        id: _string(meal['id']),
        date: DateTime.parse(_string(meal['date'])),
        prescribedMealId: meal['prescribedMealId'] as String?,
        mealType: _string(meal['mealType']),
        name: _string(meal['name']),
        order: _integer(meal['order']),
        items: _array(meal['items']).map((value) {
          final item = _object(value);
          return PlannedItem(
            id: item['id'] as String?,
            prescribedMealItemId: item['prescribedMealItemId'] as String?,
            allowedSubstitutionId: item['allowedSubstitutionId'] as String?,
            foodId: _string(item['foodId']),
            foodPortionId: item['foodPortionId'] as String?,
            quantity: _decimal(item['quantity']),
            unit: _string(item['unit']),
            order: item['order'] is int ? item['order'] as int : 0,
          );
        }).toList(),
      );
    }).toList(),
  );

  static WeeklyPlanningPreference _preference(Map<String, dynamic> json) =>
      WeeklyPlanningPreference(
        dayOfWeek: _string(json['dayOfWeek']),
        enabled: json['enabled'] is bool
            ? json['enabled'] as bool
            : throw const FormatException('Preferência inválida.'),
      );
}
