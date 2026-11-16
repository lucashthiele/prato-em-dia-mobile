import 'package:dio/dio.dart';

abstract interface class TodayRemoteDataSource {
  Future<List<dynamic>> plans();

  /// Prescribed, planned and realized nutrient totals of a civil date.
  Future<Map<String, dynamic>> dailySummary(String date);

  /// Active meal executions of a civil date (`yyyy-MM-dd`).
  Future<List<dynamic>> executions(String date);

  /// Planned items and mode of a planned meal.
  Future<Map<String, dynamic>> foodLog(String mealId);

  Future<Map<String, dynamic>> createExecution(
    String idempotencyKey,
    Map<String, dynamic> payload,
  );

  Future<Map<String, dynamic>> replaceExecution(
    String id,
    int version,
    String idempotencyKey,
    Map<String, dynamic> payload,
  );
}

class TodayApi implements TodayRemoteDataSource {
  const TodayApi(this._dio);

  final Dio _dio;

  @override
  Future<List<dynamic>> plans() async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/patients/me/weekly-plans',
    );
    return response.data ?? (throw const FormatException('Planos vazios.'));
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
  Future<Map<String, dynamic>> foodLog(String mealId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/planned-meals/$mealId/food-log',
    );
    return response.data ?? (throw const FormatException('Refeição vazia.'));
  }

  @override
  Future<Map<String, dynamic>> createExecution(
    String idempotencyKey,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/patients/me/meal-executions',
      data: payload,
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? (throw const FormatException('Registro vazio.'));
  }

  @override
  Future<Map<String, dynamic>> replaceExecution(
    String id,
    int version,
    String idempotencyKey,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/patients/me/meal-executions/$id',
      data: payload,
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {'If-Match': version, 'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? (throw const FormatException('Registro vazio.'));
  }
}
