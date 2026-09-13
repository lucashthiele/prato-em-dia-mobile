enum LoginStatus { idle, submitting, success, failure }

class LoginState {
  const LoginState({this.status = LoginStatus.idle, this.errorMessage});

  final LoginStatus status;
  final String? errorMessage;

  bool get isSubmitting => status == LoginStatus.submitting;
}
