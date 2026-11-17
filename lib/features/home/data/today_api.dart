import 'package:dio/dio.dart';

/// Sessão por cookies (M-01): nenhum header `Authorization` é montado aqui.
abstract interface class TodayRemoteDataSource {
  /// `daily-meal-categories`: as quatro categorias do dia (M-10).
  Future<Map<String, dynamic>> dailyMealCategories(String date);

  /// `calendar-periods`: planos, prescrições e dias com execução livre.
  Future<Map<String, dynamic>> calendarPeriods();

  /// Prescribed, planned and realized nutrient totals of a civil date.
  Future<Map<String, dynamic>> dailySummary(String date);

  /// Active meal executions of a civil date (`yyyy-MM-dd`).
  Future<List<dynamic>> executions(String date);

  Future<Map<String, dynamic>> deleteExecution(
    String id,
    int version,
    String idempotencyKey,
  );

  Future<void> restoreExecution(String id, String restoreToken);
}

class TodayApi implements TodayRemoteDataSource {
  const TodayApi(this._dio);

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> dailyMealCategories(String date) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/patients/me/daily-meal-categories',
      queryParameters: {'date': date},
    );
    return response.data ?? (throw const FormatException('Categorias vazias.'));
  }

  @override
  Future<Map<String, dynamic>> calendarPeriods() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/patients/me/calendar-periods',
    );
    return response.data ?? (throw const FormatException('Calendário vazio.'));
  }

  @override
  Future<Map<String, dynamic>> dailySummary(String date) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/patients/me/daily-nutrition-summary',
      queryParameters: {'date': date},
    );
    return response.data ?? (throw const FormatException('Resumo vazio.'));
  }

  @override
  Future<List<dynamic>> executions(String date) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/patients/me/meal-executions',
      queryParameters: {'date': date},
    );
    return response.data ?? (throw const FormatException('Registros vazios.'));
  }

  @override
  Future<Map<String, dynamic>> deleteExecution(
    String id,
    int version,
    String idempotencyKey,
  ) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/api/v1/patients/me/meal-executions/$id',
      options: Options(
        headers: {'If-Match': '$version', 'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? (throw const FormatException('Remoção vazia.'));
  }

  @override
  Future<void> restoreExecution(String id, String restoreToken) async {
    await _dio.post<Object?>(
      '/api/v1/patients/me/meal-executions/$id/restore',
      data: {'restoreToken': restoreToken},
      options: Options(contentType: Headers.jsonContentType),
    );
  }
}
