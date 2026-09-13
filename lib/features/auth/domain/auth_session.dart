class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.passwordChangeRequired,
  });

  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final bool passwordChangeRequired;
}
