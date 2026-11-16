import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/features/auth/data/auth_api.dart';
import 'package:prato_em_dia_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:prato_em_dia_mobile/features/auth/domain/auth_repository.dart';

DioException _error(int status, String code) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: status,
    data: {'status': status, 'code': code, 'message': 'msg', 'errors': []},
  ),
  type: DioExceptionType.badResponse,
);

void main() {
  group('login', () {
    test('reads the session flags from the body, without tokens', () async {
      final api = _FakeAuthApi();
      final session = await AuthRepositoryImpl(api)
          .login(email: '  ana@exemplo.com ', password: 'x');

      expect(api.loginEmail, 'ana@exemplo.com');
      expect(session.passwordChangeRequired, isFalse);
      expect(session.expiresIn, 900);
    });

    test('401 AUTH_INVALID_CREDENTIALS shows the generic message (A-03)', () {
      final api = _FakeAuthApi()
        ..loginError = _error(401, 'AUTH_INVALID_CREDENTIALS');
      expect(
        AuthRepositoryImpl(api).login(email: 'a@b.c', password: 'x'),
        throwsA(
          isA<AuthFailure>()
              .having(
                (f) => f.message,
                'message',
                'E-mail ou senha incorretos. Confira os dados e tente novamente.',
              )
              .having((f) => f.code, 'code', 'AUTH_INVALID_CREDENTIALS'),
        ),
      );
    });

    test('a connection failure shows the network message', () {
      final api = _FakeAuthApi()
        ..loginError = DioException.connectionError(
          requestOptions: RequestOptions(path: '/x'),
          reason: 'offline',
        );
      expect(
        AuthRepositoryImpl(api).login(email: 'a@b.c', password: 'x'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.message,
            'message',
            contains('Não foi possível conectar'),
          ),
        ),
      );
    });
  });

  group('restoreSession', () {
    test('restores the session when /me answers', () async {
      final session = await AuthRepositoryImpl(_FakeAuthApi()).restoreSession();
      expect(session?.passwordChangeRequired, isFalse);
    });

    test('keeps the restricted first-access session', () async {
      final api = _FakeAuthApi()
        ..meError = _error(403, 'PASSWORD_CHANGE_REQUIRED');
      final session = await AuthRepositoryImpl(api).restoreSession();
      expect(session?.passwordChangeRequired, isTrue);
    });

    test('returns null without a valid session', () async {
      final api = _FakeAuthApi()
        ..meError = _error(401, 'AUTHENTICATION_REQUIRED');
      expect(await AuthRepositoryImpl(api).restoreSession(), isNull);
    });
  });

  group('changePassword', () {
    test('first access sends only the new password', () async {
      final api = _FakeAuthApi();
      await AuthRepositoryImpl(api)
          .changePassword(newPassword: 'nova-senha-123');
      expect(api.sentCurrentPassword, isNull);
      expect(api.sentNewPassword, 'nova-senha-123');
    });

    test('wrong current password gets a specific message', () {
      final api = _FakeAuthApi()
        ..changeError = _error(401, 'AUTH_INVALID_CREDENTIALS');
      expect(
        AuthRepositoryImpl(
          api,
        ).changePassword(currentPassword: 'x', newPassword: 'nova-senha-123'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.message,
            'message',
            contains('senha atual não confere'),
          ),
        ),
      );
    });
  });

  test(
    'logout revokes remotely and clears the cookies even on failure',
    () async {
      var cleared = 0;
      final api = _FakeAuthApi()..logoutError = _error(500, 'INTERNAL_ERROR');
      await AuthRepositoryImpl(
        api,
        clearSession: () async => cleared++,
      ).logout();
      expect(api.logoutCalls, 1);
      expect(cleared, 1);
    },
  );
}

class _FakeAuthApi implements AuthRemoteDataSource {
  DioException? loginError;
  DioException? meError;
  DioException? changeError;
  DioException? logoutError;
  String? loginEmail;
  String? sentCurrentPassword;
  String? sentNewPassword;
  int logoutCalls = 0;

  @override
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    loginEmail = email;
    if (loginError != null) throw loginError!;
    return {'expiresIn': 900, 'passwordChangeRequired': false};
  }

  @override
  Future<void> me() async {
    if (meError != null) throw meError!;
  }

  @override
  Future<Map<String, dynamic>> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    sentCurrentPassword = currentPassword;
    sentNewPassword = newPassword;
    if (changeError != null) throw changeError!;
    return {'expiresIn': 900, 'passwordChangeRequired': false};
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    if (logoutError != null) throw logoutError!;
  }
}
