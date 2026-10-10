import 'package:dio/dio.dart';

abstract interface class WeeklyPlanningRemoteDataSource {
  Future<List<dynamic>> list();
  Future<Map<String, dynamic>> get(String planId);
  Future<Map<String, dynamic>> generate();
  Future<Map<String, dynamic>> confirm(String planId);
  Future<Map<String, dynamic>> getPreference();
  Future<Map<String, dynamic>> updatePreference({
    required String dayOfWeek,
    required bool enabled,
  });
}

class WeeklyPlanningApi implements WeeklyPlanningRemoteDataSource {
  WeeklyPlanningApi(
    this._dio, {
    required this._accessToken,
    this._tokenType = 'Bearer',
    this.renewCredentials,
  });

  final Dio _dio;
  String _accessToken;
  String _tokenType;
  final Future<({String accessToken, String tokenType})?> Function()?
  renewCredentials;

  Options get _options =>
      Options(headers: {'Authorization': '$_tokenType $_accessToken'});

  Future<Response<T>> _send<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      if (error.response?.statusCode != 401 || renewCredentials == null) {
        rethrow;
      }
      final credentials = await renewCredentials!();
      if (credentials == null) rethrow;
      _accessToken = credentials.accessToken;
      _tokenType = credentials.tokenType;
      return request();
    }
  }

  @override
  Future<List<dynamic>> list() async {
    final response = await _send(
      () => _dio.get<List<dynamic>>(
        '/api/v1/patients/me/weekly-plans',
        options: _options,
      ),
    );
    return response.data ??
        (throw const FormatException('Lista de planos vazia.'));
  }

  @override
  Future<Map<String, dynamic>> get(String planId) async {
    final response = await _send(
      () => _dio.get<Map<String, dynamic>>(
        '/api/v1/weekly-plans/$planId',
        options: _options,
      ),
    );
    return response.data ?? (throw const FormatException('Plano vazio.'));
  }

  @override
  Future<Map<String, dynamic>> generate() async {
    final response = await _send(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/patients/me/weekly-plans',
        options: _options,
      ),
    );
    return response.data ?? (throw const FormatException('Plano vazio.'));
  }

  @override
  Future<Map<String, dynamic>> confirm(String planId) async {
    final response = await _send(
      () => _dio.post<Map<String, dynamic>>(
        '/api/v1/weekly-plans/$planId/confirm',
        options: _options,
      ),
    );
    return response.data ?? (throw const FormatException('Plano vazio.'));
  }

  @override
  Future<Map<String, dynamic>> getPreference() async {
    final response = await _send(
      () => _dio.get<Map<String, dynamic>>(
        '/api/v1/patients/me/weekly-planning-preference',
        options: _options,
      ),
    );
    return response.data ?? (throw const FormatException('Preferência vazia.'));
  }

  @override
  Future<Map<String, dynamic>> updatePreference({
    required String dayOfWeek,
    required bool enabled,
  }) async {
    final response = await _send(
      () => _dio.put<Map<String, dynamic>>(
        '/api/v1/patients/me/weekly-planning-preference',
        data: {'dayOfWeek': dayOfWeek, 'enabled': enabled},
        options: _options,
      ),
    );
    return response.data ?? (throw const FormatException('Preferência vazia.'));
  }
}
