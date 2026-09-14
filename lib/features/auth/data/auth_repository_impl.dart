import 'package:dio/dio.dart';

import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import 'auth_api.dart';
import 'auth_token_store.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, this._tokenStore);

  final AuthRemoteDataSource _api;
  final AuthTokenStore _tokenStore;

  String? _accessToken;
  String? _tokenType;

  String? get accessToken => _accessToken;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final data = await _api.login(email: email.trim(), password: password);
      return await _activate(_AuthenticationPayload.fromJson(data));
    } on DioException catch (error) {
      throw AuthFailure(_messageFor(error));
    } on FormatException {
      throw const AuthFailure(
        'Não foi possível concluir o acesso. Tente novamente em instantes.',
      );
    }
  }

  @override
  Future<AuthSession> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final accessToken = _accessToken;
    final tokenType = _tokenType;
    if (accessToken == null || tokenType == null) {
      throw const AuthFailure(
        'Sua sessão não está disponível. Entre novamente para continuar.',
      );
    }

    try {
      final data = await _api.changePassword(
        accessToken: accessToken,
        tokenType: tokenType,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return await _activate(_AuthenticationPayload.fromJson(data));
    } on DioException catch (error) {
      throw AuthFailure(_passwordChangeMessageFor(error));
    } on FormatException {
      throw const AuthFailure(
        'A senha foi alterada, mas não foi possível atualizar a sessão. Entre novamente.',
      );
    }
  }

  @override
  Future<AuthSession?> restoreSession() async {
    StoredAuthSession? stored;
    try {
      stored = await _tokenStore.read();
    } on Exception {
      await _clearLocalSession();
      return null;
    }

    if (stored == null) {
      await _clearLocalSession();
      return null;
    }

    final now = DateTime.now().toUtc();
    if (now.isBefore(stored.expiresAt)) {
      try {
        await _api.validateAccessToken(
          accessToken: stored.accessToken,
          tokenType: stored.tokenType,
        );
        _accessToken = stored.accessToken;
        _tokenType = stored.tokenType;
        return AuthSession(
          accessToken: stored.accessToken,
          tokenType: stored.tokenType,
          expiresIn: stored.expiresAt.difference(now).inSeconds,
          passwordChangeRequired: stored.passwordChangeRequired,
        );
      } on Exception {
        // Token inválido ou não verificável: tente renovar antes de sair.
      }
    }

    try {
      final data = await _api.refresh(refreshToken: stored.refreshToken);
      return await _activate(_AuthenticationPayload.fromJson(data));
    } on Exception {
      await _clearLocalSession();
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try {
      final stored = await _tokenStore.read();
      final accessToken = _accessToken ?? stored?.accessToken;
      final tokenType = _tokenType ?? stored?.tokenType;

      if (stored != null && accessToken != null && tokenType != null) {
        await _api.logout(
          accessToken: accessToken,
          refreshToken: stored.refreshToken,
          tokenType: tokenType,
        );
      }
    } on Exception {
      // O logout local deve acontecer mesmo se a revogação remota falhar.
    } finally {
      await _clearLocalSession();
    }
  }

  Future<AuthSession> _activate(_AuthenticationPayload payload) async {
    final expiresAt = DateTime.now().toUtc().add(
      Duration(seconds: payload.expiresIn),
    );
    await _tokenStore.write(
      StoredAuthSession(
        accessToken: payload.accessToken,
        refreshToken: payload.refreshToken,
        tokenType: payload.tokenType,
        expiresAt: expiresAt,
        passwordChangeRequired: payload.passwordChangeRequired,
      ),
    );
    _accessToken = payload.accessToken;
    _tokenType = payload.tokenType;

    return AuthSession(
      accessToken: payload.accessToken,
      tokenType: payload.tokenType,
      expiresIn: payload.expiresIn,
      passwordChangeRequired: payload.passwordChangeRequired,
    );
  }

  Future<void> _clearLocalSession() async {
    _accessToken = null;
    _tokenType = null;
    try {
      await _tokenStore.clear();
    } on Exception {
      // A sessão em memória já foi removida.
    }
  }

  String _messageFor(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401) {
      return 'E-mail ou senha incorretos. Confira os dados e tente novamente.';
    }
    if (status == 400) {
      return 'Revise os dados informados e tente novamente.';
    }
    if (status != null && status >= 500) {
      return 'O serviço está indisponível no momento. Tente novamente em instantes.';
    }
    return 'Não foi possível conectar. Verifique sua internet e tente novamente.';
  }

  String _passwordChangeMessageFor(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401) {
      return 'A senha atual não confere. Revise e tente novamente.';
    }
    if (status == 400) {
      return 'A nova senha precisa ter entre 12 e 72 caracteres.';
    }
    if (status != null && status >= 500) {
      return 'O serviço está indisponível no momento. Tente novamente em instantes.';
    }
    return 'Não foi possível conectar. Verifique sua internet e tente novamente.';
  }
}

class _AuthenticationPayload {
  const _AuthenticationPayload({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.passwordChangeRequired,
  });

  factory _AuthenticationPayload.fromJson(Map<String, dynamic> data) {
    final accessToken = data['accessToken'];
    final refreshToken = data['refreshToken'];
    final tokenType = data['tokenType'];
    final expiresIn = data['expiresIn'];
    final passwordChangeRequired = data['passwordChangeRequired'];

    if (accessToken is! String ||
        refreshToken is! String ||
        tokenType is! String ||
        expiresIn is! num ||
        passwordChangeRequired is! bool) {
      throw const FormatException('Resposta de autenticação inválida.');
    }

    return _AuthenticationPayload(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      expiresIn: expiresIn.toInt(),
      passwordChangeRequired: passwordChangeRequired,
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final bool passwordChangeRequired;
}
