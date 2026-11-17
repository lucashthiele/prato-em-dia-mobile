/// Documento legal que o paciente precisa aceitar.
enum ConsentDocumentType {
  termsOfUse('TERMS_OF_USE'),
  privacyPolicy('PRIVACY_POLICY');

  const ConsentDocumentType(this.apiName);

  final String apiName;

  static ConsentDocumentType? fromApi(String? value) {
    for (final type in values) {
      if (type.apiName == value) return type;
    }
    return null;
  }
}

class ConsentDocumentStatus {
  const ConsentDocumentStatus({
    required this.type,
    required this.currentVersion,
    required this.accepted,
  });

  final ConsentDocumentType type;
  final String currentVersion;
  final bool accepted;
}

class ConsentStatus {
  const ConsentStatus({required this.upToDate, required this.documents});

  final bool upToDate;
  final List<ConsentDocumentStatus> documents;
}

abstract interface class ConsentRepository {
  /// `GET /me/consents`.
  Future<ConsentStatus> status();

  /// Aceita a versão vigente de cada documento ainda pendente: relê o
  /// status, faz um `POST` por documento e, num
  /// `409 CONSENT_VERSION_MISMATCH`, relê e tenta de novo.
  Future<ConsentStatus> acceptCurrent();
}

class ConsentFailure implements Exception {
  const ConsentFailure(this.message);

  final String message;
}
