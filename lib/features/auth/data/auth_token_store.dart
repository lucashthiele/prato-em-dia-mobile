import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredAuthSession {
  const StoredAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresAt,
    required this.passwordChangeRequired,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final DateTime expiresAt;
  final bool passwordChangeRequired;
}

abstract interface class AuthTokenStore {
  Future<StoredAuthSession?> read();

  Future<void> write(StoredAuthSession session);

  Future<void> clear();
}

class SecureAuthTokenStore implements AuthTokenStore {
  const SecureAuthTokenStore(this._storage);

  static const _accessTokenKey = 'auth.access_token';
  static const _refreshTokenKey = 'auth.refresh_token';
  static const _tokenTypeKey = 'auth.token_type';
  static const _expiresAtKey = 'auth.expires_at';
  static const _passwordChangeRequiredKey = 'auth.password_change_required';

  static const _keys = [
    _accessTokenKey,
    _refreshTokenKey,
    _tokenTypeKey,
    _expiresAtKey,
    _passwordChangeRequiredKey,
  ];

  final FlutterSecureStorage _storage;

  @override
  Future<StoredAuthSession?> read() async {
    final values = await Future.wait(
      _keys.map((key) => _storage.read(key: key)),
    );
    final accessToken = values[0];
    final refreshToken = values[1];
    final tokenType = values[2];
    final expiresAt = DateTime.tryParse(values[3] ?? '');
    final passwordChangeRequired = switch (values[4]) {
      'true' => true,
      'false' => false,
      _ => null,
    };

    if (accessToken == null ||
        refreshToken == null ||
        tokenType == null ||
        expiresAt == null ||
        passwordChangeRequired == null) {
      return null;
    }

    return StoredAuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      expiresAt: expiresAt,
      passwordChangeRequired: passwordChangeRequired,
    );
  }

  @override
  Future<void> write(StoredAuthSession session) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: session.accessToken),
      _storage.write(key: _refreshTokenKey, value: session.refreshToken),
      _storage.write(key: _tokenTypeKey, value: session.tokenType),
      _storage.write(
        key: _expiresAtKey,
        value: session.expiresAt.toUtc().toIso8601String(),
      ),
      _storage.write(
        key: _passwordChangeRequiredKey,
        value: session.passwordChangeRequired.toString(),
      ),
    ]);
  }

  @override
  Future<void> clear() async {
    await Future.wait(_keys.map((key) => _storage.delete(key: key)));
  }
}
