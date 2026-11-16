import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/auth_repository.dart';
import '../../domain/auth_session.dart';
import 'change_password_state.dart';

/// Os dois usos da tela de troca de senha.
enum ChangePasswordMode {
  /// Primeiro acesso (`passwordChangeRequired = true`): só a nova senha e a
  /// confirmação; o servidor dispensa a senha atual.
  firstAccess,

  /// Pelo Perfil: a senha atual é obrigatória.
  fromProfile,
}

class ChangePasswordCubit extends Cubit<ChangePasswordState> {
  ChangePasswordCubit(
    this._repository, {
    this.mode = ChangePasswordMode.firstAccess,
  }) : super(const ChangePasswordState());

  final AuthRepository _repository;
  final ChangePasswordMode mode;
  AuthSession? _session;

  Future<void> submit({
    required String newPassword,
    String? currentPassword,
  }) async {
    if (state.isSubmitting) return;
    final needsCurrent = mode == ChangePasswordMode.fromProfile;
    if (needsCurrent && (currentPassword == null || currentPassword.isEmpty)) {
      emit(
        const ChangePasswordState(
          status: ChangePasswordStatus.failure,
          errorMessage: 'Informe a senha atual.',
        ),
      );
      return;
    }
    emit(const ChangePasswordState(status: ChangePasswordStatus.submitting));
    try {
      _session = await _repository.changePassword(
        currentPassword: needsCurrent ? currentPassword : null,
        newPassword: newPassword,
      );
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
}
