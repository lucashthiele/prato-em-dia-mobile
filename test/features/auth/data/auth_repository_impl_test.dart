import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/features/auth/data/auth_api.dart';
import 'package:prato_em_dia_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:prato_em_dia_mobile/features/auth/data/auth_token_store.dart';

void main() {
  group('AuthRepositoryImpl.restoreSession', () {
    test('restores a valid access token without refreshing it', () async {
      final api = _FakeAuthApi();
      final store = _MemoryTokenStore(_storedSession(expiresIn: 300));
      final repository = AuthRepositoryImpl(api, store);

      final session = await repository.restoreSession();

      expect(session?.accessToken, 'stored-access');
      expect(api.validateCalls, 1);
      expect(api.refreshCalls, 0);
      expect(store.wasCleared, isFalse);
    });

    test(
      'refreshes an expired access token and rotates stored tokens',
      () async {
        final api = _FakeAuthApi();
        final store = _MemoryTokenStore(_storedSession(expiresIn: -10));
        final repository = AuthRepositoryImpl(api, store);

        final session = await repository.restoreSession();

        expect(session?.accessToken, 'new-access');
        expect(api.validateCalls, 0);
        expect(api.refreshCalls, 1);
        expect(store.value?.refreshToken, 'new-refresh');
      },
    );

    test('refreshes when the server rejects a valid access token', () async {
      final api = _FakeAuthApi(validateFails: true);
      final store = _MemoryTokenStore(_storedSession(expiresIn: 300));
      final repository = AuthRepositoryImpl(api, store);

      final session = await repository.restoreSession();

      expect(session?.accessToken, 'new-access');
      expect(api.validateCalls, 1);
      expect(api.refreshCalls, 1);
      expect(store.value?.refreshToken, 'new-refresh');
    });

    test('clears the session when validation and refresh both fail', () async {
      final api = _FakeAuthApi(validateFails: true, refreshFails: true);
      final store = _MemoryTokenStore(_storedSession(expiresIn: 300));
      final repository = AuthRepositoryImpl(api, store);

      final session = await repository.restoreSession();

      expect(session, isNull);
      expect(api.validateCalls, 1);
      expect(api.refreshCalls, 1);
      expect(store.wasCleared, isTrue);
    });
  });

  test('changes the password and persists the rotated session', () async {
    final api = _FakeAuthApi();
    final store = _MemoryTokenStore(_storedSession(expiresIn: 300));
    final repository = AuthRepositoryImpl(api, store);
    await repository.restoreSession();

    final session = await repository.changePassword(
      currentPassword: 'senha-inicial',
      newPassword: 'minha-nova-senha',
    );

    expect(api.lastAccessToken, 'stored-access');
    expect(api.lastCurrentPassword, 'senha-inicial');
    expect(api.lastNewPassword, 'minha-nova-senha');
    expect(session.passwordChangeRequired, isFalse);
    expect(store.value?.accessToken, 'new-access');
    expect(store.value?.refreshToken, 'new-refresh');
  });
}

StoredAuthSession _storedSession({required int expiresIn}) {
  return StoredAuthSession(
    accessToken: 'stored-access',
    refreshToken: 'stored-refresh',
    tokenType: 'Bearer',
    expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    passwordChangeRequired: false,
  );
}

class _MemoryTokenStore implements AuthTokenStore {
  _MemoryTokenStore(this.value);

  StoredAuthSession? value;
  bool wasCleared = false;

  @override
  Future<void> clear() async {
    wasCleared = true;
    value = null;
  }

  @override
  Future<StoredAuthSession?> read() async => value;

  @override
  Future<void> write(StoredAuthSession session) async {
    value = session;
  }
}

class _FakeAuthApi implements AuthRemoteDataSource {
  _FakeAuthApi({this.validateFails = false, this.refreshFails = false});

  final bool validateFails;
  final bool refreshFails;
  int validateCalls = 0;
  int refreshCalls = 0;
  String? lastAccessToken;
  String? lastCurrentPassword;
  String? lastNewPassword;

  @override
  Future<Map<String, dynamic>> changePassword({
    required String accessToken,
    required String tokenType,
    required String currentPassword,
    required String newPassword,
  }) async {
    lastAccessToken = accessToken;
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
    return _newTokens;
  }

  @override
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async => _newTokens;

  @override
  Future<void> logout({
    required String accessToken,
    required String refreshToken,
    required String tokenType,
  }) async {}

  @override
  Future<Map<String, dynamic>> refresh({required String refreshToken}) async {
    refreshCalls++;
    if (refreshFails) throw Exception('refresh failed');
    return _newTokens;
  }

  @override
  Future<void> validateAccessToken({
    required String accessToken,
    required String tokenType,
  }) async {
    validateCalls++;
    if (validateFails) throw Exception('validation failed');
  }
}

const _newTokens = <String, dynamic>{
  'accessToken': 'new-access',
  'refreshToken': 'new-refresh',
  'tokenType': 'Bearer',
  'expiresIn': 300,
  'passwordChangeRequired': false,
};
