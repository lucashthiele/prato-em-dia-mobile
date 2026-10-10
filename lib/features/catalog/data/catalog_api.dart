import 'package:dio/dio.dart';

import '../../auth/domain/auth_session.dart';

abstract interface class CatalogRemoteDataSource {
  Future<Map<String, dynamic>> list(int page);
  Future<Map<String, dynamic>> get(String id);
}

class CatalogApi implements CatalogRemoteDataSource {
  CatalogApi(this._dio, this._session, this._renewSession);

  final Dio _dio;
  AuthSession _session;
  final Future<AuthSession?> Function() _renewSession;

  Future<Map<String, dynamic>> _request(
    Future<Response<Map<String, dynamic>>> Function(String authorization) send,
  ) async {
    Future<Response<Map<String, dynamic>>> authorized() =>
        send('${_session.tokenType} ${_session.accessToken}');
    try {
      final response = await authorized();
      return response.data ?? (throw const FormatException('Resposta vazia.'));
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) rethrow;
      final renewed = await _renewSession();
      if (renewed == null) rethrow;
      _session = renewed;
      final response = await authorized();
      return response.data ?? (throw const FormatException('Resposta vazia.'));
    }
  }

  @override
  Future<Map<String, dynamic>> list(int page) => _request(
    (authorization) => _dio.get<Map<String, dynamic>>(
      '/api/v1/foods',
      queryParameters: {'page': page, 'size': 20},
      options: Options(headers: {'Authorization': authorization}),
    ),
  );

  @override
  Future<Map<String, dynamic>> get(String id) => _request(
    (authorization) => _dio.get<Map<String, dynamic>>(
      '/api/v1/foods/${Uri.encodeComponent(id)}',
      options: Options(headers: {'Authorization': authorization}),
    ),
  );
}
