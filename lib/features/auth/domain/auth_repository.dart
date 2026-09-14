import 'auth_session.dart';

abstract interface class AuthRepository {
  Future<AuthSession> login({required String email, required String password});

  Future<AuthSession> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<AuthSession?> restoreSession();

  Future<void> logout();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}
