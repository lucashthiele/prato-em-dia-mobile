import 'package:dio/dio.dart';

import 'api_events.dart';
import 'api_failure.dart';
import 'client_version.dart';

/// Marca de requisição que não deve passar pelo refresh nem pelo aceite
/// (login, refresh, logout) ou que já foi repetida uma vez.
const _skipRecovery = 'skipRecovery';
const _retried = 'retried';
const _consentGeneration = 'consentGeneration';

const refreshPath = '/api/v1/auth/refresh';
const _authPaths = ['/api/v1/auth/login', refreshPath, '/api/v1/auth/logout'];

/// Envia `X-Client-Version` em toda requisição (M-11).
class ClientVersionInterceptor extends Interceptor {
  ClientVersionInterceptor(this.value);

  final String value;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[ClientVersion.header] = value;
    handler.next(options);
  }
}

/// Recuperações automáticas da sessão por cookies:
///
/// * `426 CLIENT_OUTDATED`: avisa a interface (tela de atualização);
/// * `401` de sessão expirada: um único refresh em voo (single-flight) e uma
///   nova tentativa da requisição; se o refresh for recusado, a sessão acabou;
/// * `403 CONSENT_REQUIRED`: pede o aceite à interface e, aceito, repete a
///   requisição bloqueada.
class SessionInterceptor extends Interceptor {
  SessionInterceptor({required this.dio, required this.events});

  final Dio dio;
  final ApiEvents events;

  Future<_RefreshResult>? _refreshing;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_consentGeneration] ??= events.consentGeneration;
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final options = err.requestOptions;
    if (response == null || options.extra[_retried] == true) {
      return handler.next(err);
    }
    final failure = ApiFailure.fromDioException(err);

    if (failure.status == 426 && failure.hasCode('CLIENT_OUTDATED')) {
      events.notifyClientOutdated();
      return handler.next(err);
    }

    if (options.extra[_skipRecovery] == true ||
        _authPaths.any(options.path.endsWith)) {
      return handler.next(err);
    }

    if (failure.status == 401 &&
        (failure.code == null || failure.hasCode('AUTHENTICATION_REQUIRED'))) {
      final result = await _refresh();
      switch (result) {
        case _RefreshResult.renewed:
          return _retry(err, handler);
        case _RefreshResult.rejected:
          events.notifySessionExpired();
          return handler.next(err);
        case _RefreshResult.unreachable:
          return handler.next(err);
      }
    }

    if (failure.status == 403 && failure.hasCode('CONSENT_REQUIRED')) {
      final alreadyAccepted =
          options.extra[_consentGeneration] != events.consentGeneration;
      final accepted = alreadyAccepted || await events.requestConsent();
      return accepted ? _retry(err, handler) : handler.next(err);
    }

    handler.next(err);
  }

  Future<_RefreshResult> _refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<_RefreshResult> _doRefresh() async {
    try {
      await dio.post<Object?>(
        refreshPath,
        options: Options(extra: {_skipRecovery: true}),
      );
      return _RefreshResult.renewed;
    } on DioException catch (error) {
      return error.response == null
          ? _RefreshResult.unreachable
          : _RefreshResult.rejected;
    }
  }

  Future<void> _retry(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions..extra[_retried] = true;
    try {
      handler.resolve(await dio.fetch<Object?>(options));
    } on DioException catch (error) {
      handler.reject(error);
    }
  }
}

enum _RefreshResult { renewed, rejected, unreachable }
