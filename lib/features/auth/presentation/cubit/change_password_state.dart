enum ChangePasswordStatus { idle, submitting, success, failure }

class ChangePasswordState {
  const ChangePasswordState({
    this.status = ChangePasswordStatus.idle,
    this.errorMessage,
  });

  final ChangePasswordStatus status;
  final String? errorMessage;

  bool get isSubmitting => status == ChangePasswordStatus.submitting;
}
