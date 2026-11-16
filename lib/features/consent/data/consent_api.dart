import 'package:dio/dio.dart';

abstract interface class ConsentRemoteDataSource {
  Future<Map<String, dynamic>> status();

  Future<Map<String, dynamic>> accept({
    required String documentType,
    required String version,
  });
}

class ConsentApi implements ConsentRemoteDataSource {
  const ConsentApi(this._dio);

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> status() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/me/consents',
    );
    return response.data ?? (throw const FormatException('Aceite vazio.'));
  }

  @override
  Future<Map<String, dynamic>> accept({
    required String documentType,
    required String version,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/me/consents',
      data: {'documentType': documentType, 'version': version},
      options: Options(contentType: Headers.jsonContentType),
    );
    return response.data ?? (throw const FormatException('Aceite vazio.'));
  }
}
