import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/patient_profile.dart';
import '../../domain/profile_repository.dart';

enum ProfileStatus { loading, ready, error }

class ProfileState {
  const ProfileState({
    required this.status,
    this.profile,
    this.relationship,
    this.relationshipError,
    this.isLoadingRelationship = false,
    this.errorMessage,
    this.isSaving = false,
    this.saveMessage,
  });

  final ProfileStatus status;
  final PatientProfile? profile;
  final PatientRelationship? relationship;
  final String? relationshipError;
  final bool isLoadingRelationship;
  final String? errorMessage;
  final bool isSaving;
  final String? saveMessage;

  ProfileState copyWith({
    ProfileStatus? status,
    PatientProfile? profile,
    PatientRelationship? relationship,
    String? relationshipError,
    bool? isLoadingRelationship,
    String? errorMessage,
    bool? isSaving,
    String? saveMessage,
  }) => ProfileState(
    status: status ?? this.status,
    profile: profile ?? this.profile,
    relationship: relationship ?? this.relationship,
    relationshipError: relationshipError,
    isLoadingRelationship: isLoadingRelationship ?? this.isLoadingRelationship,
    errorMessage: errorMessage,
    isSaving: isSaving ?? this.isSaving,
    saveMessage: saveMessage,
  );
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repository)
    : super(const ProfileState(status: ProfileStatus.loading));

  final ProfileRepository _repository;

  Future<void> load() async {
    if (state.profile == null) {
      emit(const ProfileState(status: ProfileStatus.loading));
    }
    try {
      final profile = await _repository.getProfile();
      if (isClosed) return;
      emit(
        ProfileState(
          status: ProfileStatus.ready,
          profile: profile,
          isLoadingRelationship: true,
        ),
      );
      await loadRelationship();
    } on ProfileFailure catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: state.profile == null
              ? ProfileStatus.error
              : ProfileStatus.ready,
          errorMessage: error.message,
        ),
      );
    }
  }

  Future<void> loadRelationship() async {
    emit(state.copyWith(isLoadingRelationship: true));
    try {
      final relationship = await _repository.getRelationship();
      if (isClosed) return;
      emit(
        ProfileState(
          status: ProfileStatus.ready,
          profile: state.profile,
          relationship: relationship,
          isLoadingRelationship: false,
        ),
      );
    } on ProfileFailure catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          relationshipError: error.message,
          isLoadingRelationship: false,
        ),
      );
    }
  }

  Future<bool> save(PatientProfile profile) async {
    if (state.isSaving) return false;
    emit(state.copyWith(isSaving: true));
    try {
      final updated = await _repository.updateProfile(profile);
      if (isClosed) return false;
      emit(
        ProfileState(
          status: ProfileStatus.ready,
          profile: updated,
          relationship: state.relationship,
          relationshipError: state.relationshipError,
          isLoadingRelationship: state.isLoadingRelationship,
          saveMessage: 'Dados salvos.',
        ),
      );
      return true;
    } on ProfileFailure catch (error) {
      if (isClosed) return false;
      emit(state.copyWith(isSaving: false, errorMessage: error.message));
      return false;
    }
  }
}
