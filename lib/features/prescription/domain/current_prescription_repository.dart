import 'current_prescription.dart';

class PrescriptionFailure implements Exception {
  const PrescriptionFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class CurrentPrescriptionRepository {
  /// Versão vigente, ou `null` se o paciente não tem prescrição (A-01).
  Future<CurrentPrescription?> fetchCurrent();

  /// `suggestedTime` (`HH:mm`) da categoria [mealType], ou `null` (Q17).
  Future<String?> suggestedTimeFor(String mealType);
}
