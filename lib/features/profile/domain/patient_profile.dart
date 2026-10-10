class PatientProfile {
  const PatientProfile({required this.fullName, this.phone, this.birthDate});

  final String fullName;
  final String? phone;

  /// Civil date in ISO 8601 (yyyy-MM-dd); it has no timezone.
  final String? birthDate;
}

class PatientRelationship {
  const PatientRelationship({required this.nutritionistFullName});

  final String nutritionistFullName;
}
