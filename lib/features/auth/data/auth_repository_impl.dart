import 'package:dio/dio.dart';

import '../../../core/network/api_error_messages.dart';
import '../../../core/network/api_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import 'auth_api.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, {this.clearSession});

  final AuthRemoteDataSource _api;

  /// Apaga os cookies locais no logout (`ApiClient.clearSession`).
  final Future<void> Function()? clearSession;

  static const _loginMessages = {
    // A-03: conta recusada pela plataforma também volta como credencial
    // inválida; a mensagem é genérica de propósito.
    'AUTH_INVALID_CREDENTIALS':
        'E-mail ou senha incorretos. Confira os dados e tente novamente.',
  };

  static const _passwordMessages = {
    'AUTH_INVALID_CREDENTIALS':
        'A senha atual não confere. Revise e tente novamente.',
    'VALIDATION_ERROR': 'A nova senha precisa ter entre 12 e 72 caracteres.',
  };

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final data = await _api.login(email: email.trim(), password: password);
      return _sessionFrom(data);
    } on DioException catch (error) {
      throw _failure(error, _loginMessages);
    } on FormatException {
      throw const AuthFailure(
        'Não foi possível concluir o acesso. Tente novamente em instantes.',
      );
    }
  }

  @override
  Future<AuthSession> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    try {
      final data = await _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return _sessionFrom(data);
    } on DioException catch (error) {
      throw _failure(error, _passwordMessages);
    } on FormatException {
      throw const AuthFailure(
        'A senha foi alterada, mas não foi possível atualizar a sessão. Entre novamente.',
      );
    }
  }

  @override
  Future<AuthSession?> restoreSession() async {
    try {
      await _api.me();
      return const AuthSession(passwordChangeRequired: false);
    } on DioException catch (error) {
      final failure = ApiFailure.fromDioException(error);
      // Sessão restrita do primeiro acesso: ainda vale para trocar a senha.
      if (failure.status == 403 &&
          failure.hasCode('PASSWORD_CHANGE_REQUIRED')) {
        return const AuthSession(passwordChangeRequired: true);
      }
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _api.logout();
    } on Exception {
      // O logout local deve acontecer mesmo se a revogação remota falhar.
    } finally {
      try {
        await clearSession?.call();
      } on Exception {
        // Sem cookies locais a descartar.
      }
    }
  }

  AuthSession _sessionFrom(Map<String, dynamic> data) {
    final expiresIn = data['expiresIn'];
    final passwordChangeRequired = data['passwordChangeRequired'];
    if (expiresIn is! num || passwordChangeRequired is! bool) {
      throw const FormatException('Resposta de autenticação inválida.');
    }
    return AuthSession(
      expiresIn: expiresIn.toInt(),
      passwordChangeRequired: passwordChangeRequired,
    );
  }

  AuthFailure _failure(DioException error, Map<String, String> overrides) {
    final failure = ApiFailure.fromDioException(error);
    return AuthFailure(
      ApiErrorMessages.of(failure, overrides: overrides),
      code: failure.code,
    );
  }
}
