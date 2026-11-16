import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/consent.dart';

enum ConsentStatusKind { idle, accepting, accepted, failure }

class ConsentState {
  const ConsentState({this.status = ConsentStatusKind.idle, this.errorMessage});

  final ConsentStatusKind status;
  final String? errorMessage;

  bool get isAccepting => status == ConsentStatusKind.accepting;
}

class ConsentCubit extends Cubit<ConsentState> {
  ConsentCubit(this._repository) : super(const ConsentState());

  final ConsentRepository _repository;

  Future<void> accept() async {
    if (state.isAccepting) return;
    emit(const ConsentState(status: ConsentStatusKind.accepting));
    try {
      await _repository.acceptCurrent();
      emit(const ConsentState(status: ConsentStatusKind.accepted));
    } on ConsentFailure catch (failure) {
      emit(
        ConsentState(
          status: ConsentStatusKind.failure,
          errorMessage: failure.message,
        ),
      );
    } on Exception {
      emit(
        const ConsentState(
          status: ConsentStatusKind.failure,
          errorMessage: 'Não foi possível registrar o aceite. Tente novamente.',
        ),
      );
    }
  }
}
