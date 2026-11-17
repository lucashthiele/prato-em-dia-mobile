import 'package:dio/dio.dart';

/// Um campo recusado pelo servidor (`errors[]` do envelope).
class ApiFieldError {
  const ApiFieldError({this.field, this.code, this.message});

  final String? field;
  final String? code;
  final String? message;
}

/// Falha de uma chamada à API, lida do envelope do servidor
/// `{status, code, message, errors[]}`. Sem resposta (rede, tempo esgotado),
/// [status] e [code] ficam nulos e [isNetwork] é verdadeiro.
class ApiFailure implements Exception {
  const ApiFailure({
    this.status,
    this.code,
    this.message,
    this.errors = const [],
    this.isNetwork = false,
  });

  /// Lê o envelope de um [DioException]. Corpo ausente ou fora do formato
  /// resulta numa falha só com o status HTTP.
  factory ApiFailure.fromDioException(DioException error) {
    final response = error.response;
    if (response == null) return const ApiFailure(isNetwork: true);
    final data = response.data;
    if (data is Map) {
      final rawErrors = data['errors'];
      return ApiFailure(
        status: _asInt(data['status']) ?? response.statusCode,
        code: _asString(data['code']),
        message: _asString(data['message']),
        errors: [
          if (rawErrors is List)
            for (final raw in rawErrors)
              if (raw is Map)
                ApiFieldError(
                  field: _asString(raw['field']),
                  code: _asString(raw['code']),
                  message: _asString(raw['message']),
                ),
        ],
      );
    }
    return ApiFailure(status: response.statusCode);
  }

  /// Converte qualquer erro capturado. Outros tipos viram falha de rede só
  /// quando forem de conexão; o resto fica sem status nem código.
  factory ApiFailure.from(Object error) {
    if (error is ApiFailure) return error;
    if (error is DioException) return ApiFailure.fromDioException(error);
    return const ApiFailure();
  }

  final int? status;

  /// Identificador estável do erro. Os clientes decidem pelo código, nunca
  /// pelo texto de [message].
  final String? code;

  /// Texto em português do servidor; serve de reserva do mapeador.
  final String? message;
  final List<ApiFieldError> errors;
  final bool isNetwork;

  bool hasCode(String value) => code == value;

  @override
  String toString() => 'ApiFailure($status, $code)';
}

String? _asString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

int? _asInt(Object? value) => value is num ? value.toInt() : null;
