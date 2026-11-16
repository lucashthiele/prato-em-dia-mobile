import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_environment.dart';
import 'api_events.dart';
import 'api_interceptors.dart';
import 'client_version.dart';

/// O Dio compartilhado do app: cookies de sessão, `X-Client-Version`,
/// refresh single-flight e aceite de termos. Toda feature recebe [dio] por
/// construtor e não monta cabeçalho de autenticação.
class ApiClient {
  ApiClient._(this.dio, this.cookieJar, this.events);

  /// Monta o cliente. Sem [cookieJar], usa o `PersistCookieJar` no diretório
  /// de suporte do app (sobrevive ao fechamento do app).
  static Future<ApiClient> create({
    String? baseUrl,
    String? clientVersion,
    CookieJar? cookieJar,
    HttpClientAdapter? httpClientAdapter,
  }) async {
    final jar = cookieJar ?? await _persistentJar();
    final version = clientVersion ?? await ClientVersion.current();
    return ApiClient.withJar(
      baseUrl: baseUrl ?? AppEnvironment.apiBaseUrl,
      clientVersion: version,
      cookieJar: jar,
      httpClientAdapter: httpClientAdapter,
    );
  }

  /// Versão síncrona, para testes e composição com um jar já pronto.
  factory ApiClient.withJar({
    required String baseUrl,
    required String clientVersion,
    required CookieJar cookieJar,
    HttpClientAdapter? httpClientAdapter,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        headers: const {'Accept': 'application/json'},
      ),
    );
    if (httpClientAdapter != null) dio.httpClientAdapter = httpClientAdapter;
    final events = ApiEvents();
    dio.interceptors.addAll([
      ClientVersionInterceptor(clientVersion),
      CookieManager(cookieJar),
      SessionInterceptor(dio: dio, events: events),
    ]);
    return ApiClient._(dio, cookieJar, events);
  }

  final Dio dio;
  final CookieJar cookieJar;
  final ApiEvents events;

  /// Descarta os cookies de sessão (logout local).
  Future<void> clearSession() => cookieJar.deleteAll();

  static Future<CookieJar> _persistentJar() async {
    final directory = await getApplicationSupportDirectory();
    return PersistCookieJar(storage: FileStorage('${directory.path}/cookies'));
  }
}
