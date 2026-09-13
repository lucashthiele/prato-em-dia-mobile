import 'package:dio/dio.dart';

abstract interface class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  });

  Future<Map<String, dynamic>> refresh({required String refreshToken});

  Future<void> validateAccessToken({
    required String accessToken,
    required String tokenType,
  });

  Future<void> logout({
    required String accessToken,
    required String refreshToken,
    required String tokenType,
  });
}

class AuthApi implements AuthRemoteDataSource {
  const AuthApi(this._dio);

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/login',
      data: {'email': email, 'password': password},
      options: Options(contentType: Headers.jsonContentType),
    );

    final data = response.data;
    if (data == null) {
      throw const FormatException('Resposta de autenticação vazia.');
    }
    return data;
  }

  @override
  Future<Map<String, dynamic>> refresh({required String refreshToken}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/refresh',
      data: {'refreshToken': refreshToken},
      options: Options(contentType: Headers.jsonContentType),
    );

    final data = response.data;
    if (data == null) {
      throw const FormatException('Resposta de renovação vazia.');
    }
    return data;
  }

  @override
  Future<void> validateAccessToken({
    required String accessToken,
    required String tokenType,
  }) async {
    try {
      await _dio.get<Object?>(
        '/api/v1/me',
        options: Options(headers: {'Authorization': '$tokenType $accessToken'}),
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      final code = data is Map<String, dynamic> ? data['code'] : null;
      if (error.response?.statusCode == 403 &&
          code == 'PASSWORD_CHANGE_REQUIRED') {
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> logout({
    required String accessToken,
    required String refreshToken,
    required String tokenType,
  }) async {
    await _dio.post<void>(
      '/api/v1/auth/logout',
      data: {'refreshToken': refreshToken},
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {'Authorization': '$tokenType $accessToken'},
      ),
    );
  }
}
