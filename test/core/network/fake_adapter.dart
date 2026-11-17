import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:prato_em_dia_mobile/core/network/api_client.dart';

typedef FakeHandler = ResponseBody Function(RequestOptions options);

/// Adaptador HTTP em memória: registra as requisições e responde por função.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  FakeHandler handler;
  final List<RequestOptions> requests = [];

  int count(String path) => requests.where((r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    // Cede o controle para que requisições "simultâneas" se intercalem.
    await Future<void>.delayed(Duration.zero);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(
  int status,
  Object? body, {
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...headers,
  },
);

ResponseBody errorEnvelope(
  int status,
  String code, [
  String message = 'Erro',
]) => json(status, {
  'status': status,
  'code': code,
  'message': message,
  'errors': [],
});

ApiClient testClient(FakeAdapter adapter, {CookieJar? jar}) =>
    ApiClient.withJar(
      baseUrl: 'http://api.test',
      clientVersion: 'android/0.1.0+1',
      cookieJar: jar ?? CookieJar(),
      httpClientAdapter: adapter,
    );
