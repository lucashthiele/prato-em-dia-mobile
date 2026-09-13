import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/auth_repository.dart';
import '../../domain/auth_session.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._repository) : super(const LoginState());

  final AuthRepository _repository;

  Future<void> submit({required String email, required String password}) async {
    if (state.isSubmitting) return;

    emit(const LoginState(status: LoginStatus.submitting));
    try {
      final session = await _repository.login(email: email, password: password);
      _lastSession = session;
      emit(const LoginState(status: LoginStatus.success));
    } on AuthFailure catch (failure) {
      emit(
        LoginState(status: LoginStatus.failure, errorMessage: failure.message),
      );
    } catch (_) {
      emit(
        const LoginState(
          status: LoginStatus.failure,
          errorMessage: 'Algo deu errado. Tente novamente em instantes.',
        ),
      );
    }
  }

  AuthSession? _lastSession;

  AuthSession? takeSession() {
    final session = _lastSession;
    _lastSession = null;
    return session;
  }
}
