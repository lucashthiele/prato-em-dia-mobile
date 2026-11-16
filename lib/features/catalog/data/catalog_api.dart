import 'package:dio/dio.dart';

abstract interface class CatalogRemoteDataSource {
  Future<Map<String, dynamic>> list(int page, {String? query});
  Future<Map<String, dynamic>> get(String id);
}

class CatalogApi implements CatalogRemoteDataSource {
  CatalogApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> _request(
    Future<Response<Map<String, dynamic>>> Function() send,
  ) async {
    final response = await send();
    return response.data ?? (throw const FormatException('Resposta vazia.'));
  }

  @override
  Future<Map<String, dynamic>> list(int page, {String? query}) => _request(
    () => _dio.get<Map<String, dynamic>>(
      '/api/v1/foods',
      queryParameters: {
        'page': page,
        'size': 20,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    ),
  );

  @override
  Future<Map<String, dynamic>> get(String id) => _request(
    () => _dio.get<Map<String, dynamic>>(
      '/api/v1/foods/${Uri.encodeComponent(id)}',
    ),
  );
}
