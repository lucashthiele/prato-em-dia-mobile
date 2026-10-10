import 'package:dio/dio.dart';

import '../../auth/domain/auth_session.dart';
import '../domain/patient_profile.dart';
import '../domain/profile_repository.dart';

class ProfileApi implements ProfileRepository {
  ProfileApi(this._dio, AuthSession session, {this.refreshSession})
    : _session = session;

  final Dio _dio;
  AuthSession _session;
  final Future<AuthSession?> Function()? refreshSession;

  Options get _options => Options(
    contentType: Headers.jsonContentType,
    headers: {'Authorization': '${_session.tokenType} ${_session.accessToken}'},
  );

  @override
  Future<PatientProfile> getProfile() async {
    try {
      final response = await _request(
        (options) =>
            _dio.get<Map<String, dynamic>>('/api/v1/me', options: options),
      );
      return _profileFrom(response.data);
    } on DioException catch (error) {
      throw ProfileFailure(_messageFor(error));
    } on FormatException {
      throw const ProfileFailure(
        'Não foi possível ler seus dados. Tente novamente.',
      );
    }
  }

  @override
  Future<PatientRelationship?> getRelationship() async {
    try {
      final response = await _request(
        (options) => _dio.get<Map<String, dynamic>>(
          '/api/v1/patients/me/relationship',
          options: options,
        ),
      );
      final name = response.data?['nutritionistFullName'];
      if (name is! String || name.trim().isEmpty) {
        throw const FormatException('Vínculo inválido.');
      }
      return PatientRelationship(nutritionistFullName: name);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw ProfileFailure(_messageFor(error));
    } on FormatException {
      throw const ProfileFailure(
        'Não foi possível ler seu vínculo. Tente novamente.',
      );
    }
  }

  @override
  Future<PatientProfile> updateProfile(PatientProfile profile) async {
    try {
      final response = await _request(
        (options) => _dio.put<Map<String, dynamic>>(
          '/api/v1/me',
          data: {
            'fullName': profile.fullName.trim(),
            'phone': (profile.phone?.trim().isEmpty ?? true)
                ? null
                : profile.phone!.trim(),
            'registrationNumber': null,
            'bio': null,
            'birthDate': profile.birthDate,
          },
          options: options,
        ),
      );
      return _profileFrom(response.data);
    } on DioException catch (error) {
      throw ProfileFailure(_messageFor(error));
    } on FormatException {
      throw const ProfileFailure(
        'Não foi possível confirmar a atualização. Recarregue seus dados.',
      );
    }
  }

  Future<Response<Map<String, dynamic>>> _request(
    Future<Response<Map<String, dynamic>>> Function(Options) call,
  ) async {
    try {
      return await call(_options);
    } on DioException catch (error) {
      if (error.response?.statusCode != 401 || refreshSession == null) rethrow;
      AuthSession? renewed;
      try {
        renewed = await refreshSession!();
      } on Exception {
        throw const ProfileFailure(
          'Sua sessão expirou. Saia e entre novamente.',
        );
      }
      if (renewed == null) {
        throw const ProfileFailure(
          'Sua sessão expirou. Saia e entre novamente.',
        );
      }
      _session = renewed;
      return call(_options);
    }
  }

  PatientProfile _profileFrom(Map<String, dynamic>? data) {
    final name = data?['fullName'];
    final phone = data?['phone'];
    final birthDate = data?['birthDate'];
    if (name is! String ||
        name.trim().isEmpty ||
        (phone != null && phone is! String) ||
        (birthDate != null && birthDate is! String)) {
      throw const FormatException('Perfil inválido.');
    }
    return PatientProfile(
      fullName: name,
      phone: phone as String?,
      birthDate: birthDate as String?,
    );
  }

  String _messageFor(DioException error) {
    switch (error.response?.statusCode) {
      case 400:
        return 'Revise os dados informados e tente novamente.';
      case 401:
        return 'Sua sessão expirou. Saia e entre novamente.';
      case 403:
        return 'Você não tem acesso a estes dados.';
      case 409:
        return 'Seus dados mudaram. Recarregue e tente novamente.';
      default:
        return 'Não foi possível conectar. Verifique sua internet e tente novamente.';
    }
  }
}
