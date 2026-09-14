import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/auth_repository.dart';
import '../../domain/auth_session.dart';
import 'change_password_state.dart';

class ChangePasswordCubit extends Cubit<ChangePasswordState> {
  ChangePasswordCubit(this._repository, this._currentPassword)
    : super(const ChangePasswordState());

  final AuthRepository _repository;
  String? _currentPassword;
  AuthSession? _session;

  Future<void> submit({required String newPassword}) async {
    if (state.isSubmitting) return;
    final currentPassword = _currentPassword;
    if (currentPassword == null) {
      emit(
        const ChangePasswordState(
          status: ChangePasswordStatus.failure,
          errorMessage: 'Entre novamente para criar sua senha pessoal.',
        ),
      );
      return;
    }
    emit(const ChangePasswordState(status: ChangePasswordStatus.submitting));
    try {
      _session = await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _currentPassword = null;
      emit(const ChangePasswordState(status: ChangePasswordStatus.success));
    } on AuthFailure catch (failure) {
      emit(
        ChangePasswordState(
          status: ChangePasswordStatus.failure,
          errorMessage: failure.message,
        ),
      );
    } on Exception {
      emit(
        const ChangePasswordState(
          status: ChangePasswordStatus.failure,
          errorMessage: 'Não foi possível alterar sua senha. Tente novamente em instantes.',
        ),
      );
    }
  }

  AuthSession? takeSession() {
    final session = _session;
    _session = null;
    return session;
  }

  @override
  Future<void> close() {
    _currentPassword = null;
    return super.close();
  }
}
