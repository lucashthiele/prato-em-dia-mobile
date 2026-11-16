import 'auth_session.dart';

abstract interface class AuthRepository {
  Future<AuthSession> login({required String email, required String password});

  /// Troca a senha. [currentPassword] é obrigatória fora do primeiro acesso
  /// (`passwordChangeRequired = false`) e ignorada pelo servidor no primeiro
  /// acesso.
  Future<AuthSession> changePassword({
    String? currentPassword,
    required String newPassword,
  });

  /// Restaura a sessão a partir dos cookies (`GET /me`, com refresh se
  /// preciso). Devolve `null` sem sessão válida.
  Future<AuthSession?> restoreSession();

  Future<void> logout();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code});

  final String message;

  /// Código do erro do servidor, quando houve resposta.
  final String? code;
}
