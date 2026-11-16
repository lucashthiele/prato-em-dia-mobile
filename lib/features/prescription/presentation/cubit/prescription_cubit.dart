import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/current_prescription.dart';
import '../../domain/current_prescription_repository.dart';

enum PrescriptionStatus { loading, ready, empty, error }

/// Resolve o nome de um alimento; o servidor só devolve o `foodId`.
typedef FoodNameResolver = Future<String?> Function(String foodId);

class PrescriptionState {
  const PrescriptionState({
    required this.status,
    this.prescription,
    this.foodNames = const {},
    this.errorMessage,
  });

  final PrescriptionStatus status;
  final CurrentPrescription? prescription;
  final Map<String, String> foodNames;
  final String? errorMessage;
}

class PrescriptionCubit extends Cubit<PrescriptionState> {
  PrescriptionCubit(this._repository, {this.resolveFoodName})
    : super(const PrescriptionState(status: PrescriptionStatus.loading));

  final CurrentPrescriptionRepository _repository;
  final FoodNameResolver? resolveFoodName;

  Future<void> load() async {
    emit(const PrescriptionState(status: PrescriptionStatus.loading));
    try {
      final prescription = await _repository.fetchCurrent();
      if (isClosed) return;
      if (prescription == null) {
        emit(const PrescriptionState(status: PrescriptionStatus.empty));
        return;
      }
      emit(
        PrescriptionState(
          status: PrescriptionStatus.ready,
          prescription: prescription,
        ),
      );
      await _loadFoodNames(prescription);
    } on PrescriptionFailure catch (error) {
      _fail(error.message);
    } catch (_) {
      _fail('Não foi possível carregar sua prescrição. Tente novamente.');
    }
  }

  void _fail(String message) {
    if (isClosed) return;
    emit(
      PrescriptionState(
        status: PrescriptionStatus.error,
        errorMessage: message,
      ),
    );
  }

  Future<void> _loadFoodNames(CurrentPrescription prescription) async {
    final resolve = resolveFoodName;
    if (resolve == null) return;
    final ids = <String>{
      for (final meal in prescription.meals)
        for (final item in meal.items) ...[
          item.foodId,
          for (final s in item.substitutions) s.foodId,
        ],
    };
    final names = <String, String>{};
    await Future.wait(
      ids.map((id) async {
        try {
          final name = await resolve(id);
          if (name != null && name.isNotEmpty) names[id] = name;
        } catch (_) {}
      }),
    );
    if (isClosed || names.isEmpty) return;
    emit(
      PrescriptionState(
        status: PrescriptionStatus.ready,
        prescription: prescription,
        foodNames: names,
      ),
    );
  }
}
