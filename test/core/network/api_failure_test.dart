import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/core/network/api_error_messages.dart';
import 'package:prato_em_dia_mobile/core/network/api_failure.dart';

DioException _error(int status, Object? data) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: status,
    data: data,
  ),
  type: DioExceptionType.badResponse,
);

void main() {
  group('ApiFailure', () {
    test('reads the server envelope', () {
      final failure = ApiFailure.fromDioException(
        _error(400, {
          'status': 400,
          'code': 'VALIDATION_ERROR',
          'message': 'Dados inválidos.',
          'errors': [
            {'field': 'newPassword', 'code': 'SIZE', 'message': 'Tamanho.'},
          ],
        }),
      );

      expect(failure.status, 400);
      expect(failure.code, 'VALIDATION_ERROR');
      expect(failure.message, 'Dados inválidos.');
      expect(failure.errors.single.field, 'newPassword');
      expect(failure.isNetwork, isFalse);
    });

    test('falls back to the HTTP status for a body outside the envelope', () {
      final failure = ApiFailure.fromDioException(_error(502, '<html/>'));
      expect(failure.status, 502);
      expect(failure.code, isNull);
    });

    test('marks a missing response as a network failure', () {
      final failure = ApiFailure.fromDioException(
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/x'),
          reason: 'offline',
        ),
      );
      expect(failure.isNetwork, isTrue);
    });
  });

  group('ApiErrorMessages', () {
    ApiFailure failure({String? code, String? message, int status = 400}) =>
        ApiFailure(status: status, code: code, message: message);

    test('maps every catalog code to a pt-BR message', () {
      for (final entry in ApiErrorMessages.catalog.entries) {
        expect(
          ApiErrorMessages.of(failure(code: entry.key, message: 'outra')),
          entry.value,
        );
      }
      expect(
        ApiErrorMessages.catalog.keys,
        containsAll([
          'AUTH_INVALID_CREDENTIALS',
          'CONSENT_REQUIRED',
          'CONSENT_VERSION_MISMATCH',
          'CLIENT_OUTDATED',
          'WEEKLY_PLAN_GENERATION_CONFLICT',
          'PRESCRIPTION_NOT_FOUND',
          'NO_ALLOWED_FOODS',
          'TRACKING_INVALID',
        ]),
      );
    });

    test('uses the server message for an unknown code', () {
      expect(
        ApiErrorMessages.of(
          failure(code: 'NOVO_CODIGO', message: 'Texto do servidor.'),
        ),
        'Texto do servidor.',
      );
    });

    test('lets the screen override the message of a code', () {
      expect(
        ApiErrorMessages.of(
          failure(code: 'AUTH_INVALID_CREDENTIALS'),
          overrides: {'AUTH_INVALID_CREDENTIALS': 'Senha atual incorreta.'},
        ),
        'Senha atual incorreta.',
      );
    });

    test('has a network message and a server-down message', () {
      expect(
        ApiErrorMessages.of(const ApiFailure(isNetwork: true)),
        ApiErrorMessages.network,
      );
      expect(
        ApiErrorMessages.of(failure(status: 503)),
        ApiErrorMessages.serverUnavailable,
      );
    });

    test('falls back to the given text without code, message or status', () {
      expect(
        ApiErrorMessages.of(const ApiFailure(), fallback: 'Reserva.'),
        'Reserva.',
      );
      expect(ApiErrorMessages.of(const ApiFailure()), ApiErrorMessages.generic);
    });

    test('ofError reads a DioException', () {
      expect(
        ApiErrorMessages.ofError(
          _error(403, {'status': 403, 'code': 'ACCESS_DENIED', 'message': 'x'}),
        ),
        ApiErrorMessages.catalog['ACCESS_DENIED'],
      );
    });
  });
}
