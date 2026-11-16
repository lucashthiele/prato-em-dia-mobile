import 'package:dio/dio.dart';

import '../domain/current_prescription.dart';
import '../domain/current_prescription_repository.dart';
import 'current_prescription_mapper.dart';

/// Sessão por cookies (M-01): nenhum header `Authorization` é montado aqui.
class CurrentPrescriptionApi implements CurrentPrescriptionRepository {
  CurrentPrescriptionApi(this._dio);

  final Dio _dio;

  @override
  Future<CurrentPrescription?> fetchCurrent() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/patients/me/prescriptions/current',
      );
      final data = response.data;
      if (data == null) throw const FormatException('Resposta vazia.');
      return currentPrescriptionFromJson(data);
    } on DioException catch (error) {
      if (_isNotFound(error)) return null;
      rethrow;
    }
  }

  @override
  Future<String?> suggestedTimeFor(String mealType) async =>
      (await fetchCurrent())?.suggestedTimeFor(mealType);

  static bool _isNotFound(DioException error) {
    final response = error.response;
    if (response?.statusCode != 404) return false;
    final data = response?.data;
    return data is Map && data['code'] == 'PRESCRIPTION_NOT_FOUND';
  }
}
