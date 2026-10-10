import 'patient_profile.dart';

abstract interface class ProfileRepository {
  Future<PatientProfile> getProfile();
  Future<PatientRelationship?> getRelationship();
  Future<PatientProfile> updateProfile(PatientProfile profile);
}

class ProfileFailure implements Exception {
  const ProfileFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
