import 'package:dio/dio.dart';

import '../../../core/network/api_error_messages.dart';
import '../../../core/network/api_failure.dart';
import '../domain/consent.dart';
import 'consent_api.dart';

class ConsentRepositoryImpl implements ConsentRepository {
  const ConsentRepositoryImpl(this._api);

  final ConsentRemoteDataSource _api;

  /// Tentativas depois de um `409 CONSENT_VERSION_MISMATCH`.
  static const _maxMismatchRetries = 2;

  @override
  Future<ConsentStatus> status() =>
      _guard(() async => _parse(await _api.status()));

  @override
  Future<ConsentStatus> acceptCurrent() => _guard(() async {
    var mismatches = 0;
    var status = _parse(await _api.status());
    while (true) {
      final pending = status.documents.where((d) => !d.accepted).toList();
      if (pending.isEmpty) return status;
      try {
        for (final document in pending) {
          status = _parse(
            await _api.accept(
              documentType: document.type.apiName,
              version: document.currentVersion,
            ),
          );
        }
        return status;
      } on DioException catch (error) {
        final failure = ApiFailure.fromDioException(error);
        if (!failure.hasCode('CONSENT_VERSION_MISMATCH') ||
            mismatches >= _maxMismatchRetries) {
          rethrow;
        }
        mismatches++;
        status = _parse(await _api.status());
      }
    }
  });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (error) {
      throw ConsentFailure(ApiErrorMessages.ofError(error));
    } on FormatException {
      throw const ConsentFailure(
        'Não foi possível ler o aceite dos termos. Tente novamente.',
      );
    }
  }

  ConsentStatus _parse(Map<String, dynamic> data) {
    final upToDate = data['upToDate'];
    final documents = data['documents'];
    if (upToDate is! bool || documents is! List) {
      throw const FormatException('Aceite inválido.');
    }
    return ConsentStatus(
      upToDate: upToDate,
      documents: [
        for (final raw in documents)
          if (raw is Map<String, dynamic>)
            if (ConsentDocumentType.fromApi(raw['documentType'] as String?)
                case final type?)
              ConsentDocumentStatus(
                type: type,
                currentVersion: raw['currentVersion'] as String,
                accepted: raw['accepted'] == true,
              ),
      ],
    );
  }
}
