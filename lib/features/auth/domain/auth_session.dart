/// Estado da sessão do paciente. Os tokens vivem só nos cookies `HttpOnly`
/// do Dio compartilhado; o app não os lê nem os guarda.
class AuthSession {
  const AuthSession({required this.passwordChangeRequired, this.expiresIn = 0});

  /// Segundos de validade do access token no momento do login (informativo).
  final int expiresIn;

  /// Primeiro acesso: a sessão só vale para trocar a senha.
  final bool passwordChangeRequired;
}
