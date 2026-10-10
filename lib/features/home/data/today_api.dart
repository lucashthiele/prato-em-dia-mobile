import 'package:dio/dio.dart';

abstract interface class TodayRemoteDataSource {
  Future<List<dynamic>> plans(String authorization);

  Future<Map<String, dynamic>> events(String authorization, int page);

  Future<Map<String, dynamic>> record(
    String authorization,
    String mealId,
    String idempotencyKey,
    Map<String, dynamic> payload,
  );
}

class TodayApi implements TodayRemoteDataSource {
  const TodayApi(this._dio);

  final Dio _dio;

  @override
  Future<List<dynamic>> plans(String authorization) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/patients/me/weekly-plans',
      options: Options(headers: {'Authorization': authorization}),
    );
    return response.data ?? (throw const FormatException('Planos vazios.'));
  }

  @override
  Future<Map<String, dynamic>> events(String authorization, int page) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/patients/me/completion-events',
      queryParameters: {'page': page, 'size': 20},
      options: Options(headers: {'Authorization': authorization}),
    );
    return response.data ?? (throw const FormatException('Eventos vazios.'));
  }

  @override
  Future<Map<String, dynamic>> record(
    String authorization,
    String mealId,
    String idempotencyKey,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/planned-meals/$mealId/completion-events',
      data: payload,
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {
          'Authorization': authorization,
          'Idempotency-Key': idempotencyKey,
        },
      ),
    );
    return response.data ?? (throw const FormatException('Evento vazio.'));
  }
}
