import 'package:dio/dio.dart';

abstract interface class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  });

  /// `GET /me`: devolve os dados da conta, ou lança o erro do servidor.
  Future<void> me();

  Future<Map<String, dynamic>> changePassword({
    String? currentPassword,
    required String newPassword,
  });

  Future<void> logout();
}

/// Chamadas de autenticação. A sessão vai nos cookies do Dio compartilhado:
/// login, troca de senha e logout não trazem nem enviam tokens no corpo.
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
    return response.data ??
        (throw const FormatException('Resposta de autenticação vazia.'));
  }

  @override
  Future<void> me() async {
    await _dio.get<Object?>('/api/v1/me');
  }

  @override
  Future<Map<String, dynamic>> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/v1/me/password',
      data: {'currentPassword': ?currentPassword, 'newPassword': newPassword},
      options: Options(contentType: Headers.jsonContentType),
    );
    return response.data ??
        (throw const FormatException('Resposta de alteração de senha vazia.'));
  }

  @override
  Future<void> logout() async {
    await _dio.post<void>('/api/v1/auth/logout');
  }
}
