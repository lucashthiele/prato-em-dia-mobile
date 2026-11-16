import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/today_repository.dart';

class TodayState {
  const TodayState({
    this.data,
    this.loading = false,
    this.error,
    this.busy = false,
    this.actionError,
  });

  final TodayData? data;
  final bool loading;
  final String? error;

  /// Remoção ou desfazer em andamento.
  final bool busy;
  final String? actionError;
}

class TodayCubit extends Cubit<TodayState> {
  TodayCubit(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const TodayState());

  final TodayRepository _repository;
  final DateTime Function() _now;
  DateTime? _date;
  int _loadGeneration = 0;

  /// Dia aberto; recarregar sem [date] mantém o dia atual da tela.
  DateTime get date => _date ?? civilDay(_now());

  Future<void> load({DateTime? date, bool clearData = false}) async {
    if (date != null) _date = civilDay(date);
    final generation = ++_loadGeneration;
    emit(TodayState(data: clearData ? null : state.data, loading: true));
    try {
      final data = await _repository.load(this.date);
      if (isClosed || generation != _loadGeneration) return;
      emit(TodayState(data: data));
    } on TodayFailure catch (error) {
      if (isClosed || generation != _loadGeneration) return;
      emit(
        TodayState(data: clearData ? null : state.data, error: error.message),
      );
    }
  }

  /// Remove a execução e recarrega o dia. Devolve o token para o Desfazer, ou
  /// nulo se a remoção falhou (o erro vai em [TodayState.actionError]).
  Future<RemovedExecution?> remove(DayExecution execution) async {
    if (state.busy) return null;
    emit(TodayState(data: state.data, busy: true));
    try {
      final removed = await _repository.remove(execution);
      await _reload();
      return removed;
    } on TodayFailure catch (error) {
      if (!isClosed) {
        emit(TodayState(data: state.data, actionError: error.message));
      }
      return null;
    }
  }

  Future<bool> restore(RemovedExecution removed) async {
    if (state.busy) return false;
    emit(TodayState(data: state.data, busy: true));
    try {
      await _repository.restore(removed);
      await _reload();
      return true;
    } on TodayFailure catch (error) {
      // Token vencido ou conflito: mostra o erro e relê o dia.
      if (!isClosed) {
        emit(TodayState(data: state.data, actionError: error.message));
        await _reload(keepActionError: error.message);
      }
      return false;
    }
  }

  Future<void> _reload({String? keepActionError}) async {
    final generation = ++_loadGeneration;
    try {
      final data = await _repository.load(date);
      if (isClosed || generation != _loadGeneration) return;
      emit(TodayState(data: data, actionError: keepActionError));
    } on TodayFailure catch (error) {
      if (isClosed || generation != _loadGeneration) return;
      emit(TodayState(data: state.data, error: error.message));
    }
  }
}
