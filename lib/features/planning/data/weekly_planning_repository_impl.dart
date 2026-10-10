import 'package:dio/dio.dart';

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
      final status = error.response?.statusCode;
      if (status == 401) {
        throw const PlanningFailure(
          'Sua sessão expirou. Entre novamente para continuar.',
        );
      }
      if (status == 403) {
        throw const PlanningFailure('Você não tem acesso a este planejamento.');
      }
      if (status == 404) {
        throw const PlanningFailure(
          'Plano não encontrado. Atualize a lista.',
          isNotFound: true,
        );
      }
      if (status == 409) {
        throw const PlanningFailure(
          'O plano mudou. Atualize antes de continuar.',
          isConflict: true,
        );
      }
      if (status == 400 || status == 422) {
        throw const PlanningFailure(
          'Não foi possível concluir esta ação. Confira o plano e tente novamente.',
        );
      }
      if (status != null && status >= 500) {
        throw const PlanningFailure(
          'Serviço indisponível. Tente novamente em instantes.',
        );
      }
      throw const PlanningFailure(
        'Não foi possível conectar. Confira sua internet e tente novamente.',
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
        time: meal['time'] as String?,
        mealType: _string(meal['mealType']),
        name: _string(meal['name']),
        order: _integer(meal['order']),
        items: _array(meal['items']).map((value) {
          final item = _object(value);
          return PlannedItem(
            foodId: _string(item['foodId']),
            quantity: _decimal(item['quantity']),
            unit: _string(item['unit']),
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
