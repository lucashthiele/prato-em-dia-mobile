import 'dart:math';

import 'package:dio/dio.dart';

import '../../../core/network/api_error_messages.dart';
import '../../prescription/domain/current_prescription.dart';
import '../../prescription/domain/current_prescription_repository.dart';
import '../domain/today_repository.dart';
import 'today_api.dart';

class TodayRepositoryImpl implements TodayRepository {
  TodayRepositoryImpl(this._api, this._prescriptions);

  final TodayRemoteDataSource _api;
  final CurrentPrescriptionRepository _prescriptions;

  @override
  Future<TodayData> load(DateTime date) => _guard(() async {
    final day = formatCivilDate(date);
    // Categorias e execuções são o núcleo da tela; o resto é secundário e
    // falha sem derrubar o dia.
    final calendar = _calendar();
    final summary = _summary(day);
    final prescription = _prescription();
    final categories = await _api.dailyMealCategories(day);
    final executions = await _executions(day);
    final current = await prescription;
    return TodayData(
      date: civilDay(date),
      categories: parseCategories(
        categories,
        executions: executions,
        suggestedTime: (type) =>
            _hhmm(current.prescription?.suggestedTimeFor(type)),
      ),
      calendar: await calendar,
      summary: await summary,
      hasPrescription: current.known ? current.prescription != null : true,
    );
  }, 'Não foi possível ler as refeições. Tente novamente.');

  Future<Map<String, List<DayExecution>>> _executions(String day) async {
    final result = <String, List<DayExecution>>{};
    for (final raw in await _api.executions(day)) {
      final execution = parseExecution(_object(raw));
      (result[execution.mealType] ??= []).add(execution);
    }
    for (final list in result.values) {
      list.sort((a, b) => (a.time ?? '').compareTo(b.time ?? ''));
    }
    return result;
  }

  Future<CalendarPeriods?> _calendar() async {
    try {
      return parseCalendar(await _api.calendarPeriods());
    } on Exception {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<DailySummary?> _summary(String day) async {
    try {
      return parseSummary(await _api.dailySummary(day));
    } on Exception {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// `known` é falso quando a consulta falhou: nesse caso o app não afirma que
  /// o paciente está sem prescrição.
  Future<({bool known, CurrentPrescription? prescription})>
  _prescription() async {
    try {
      return (known: true, prescription: await _prescriptions.fetchCurrent());
    } on Exception {
      return (known: false, prescription: null);
    } on TypeError {
      return (known: false, prescription: null);
    }
  }

  @override
  Future<RemovedExecution> remove(DayExecution execution) => _guard(() async {
    final data = await _api.deleteExecution(
      execution.id,
      execution.version,
      _newKey(),
    );
    return RemovedExecution(
      id: execution.id,
      restoreToken: data['restoreToken'] as String,
      restoreExpiresAt: DateTime.parse(data['restoreExpiresAt'] as String),
    );
  }, 'Não foi possível remover o registro. Tente novamente.');

  @override
  Future<void> restore(RemovedExecution removed) => _guard(
    () => _api.restoreExecution(removed.id, removed.restoreToken),
    'Não foi possível desfazer a remoção. Tente novamente.',
  );

  Future<T> _guard<T>(Future<T> Function() action, String unreadable) async {
    try {
      return await action();
    } on TodayFailure {
      rethrow;
    } on DioException catch (error) {
      throw TodayFailure(ApiErrorMessages.ofError(error));
    } on FormatException {
      throw TodayFailure(unreadable);
    } on TypeError {
      throw TodayFailure(unreadable);
    }
  }
}

/// `daily-meal-categories` → categorias, na ordem do servidor. O estado vem do
/// servidor; o app só anexa execuções, horário sugerido e a ação de registro.
List<DayCategory> parseCategories(
  Map<String, dynamic> data, {
  Map<String, List<DayExecution>> executions = const {},
  String? Function(String mealType)? suggestedTime,
}) => [
  for (final raw in data['categories'] as List<dynamic>)
    () {
      final c = _object(raw);
      final type = c['mealType'] as String;
      final state =
          CategoryState.fromCode(c['state']) ??
          (throw const FormatException('Estado inválido.'));
      return DayCategory(
        mealType: type,
        state: state,
        canRegister: c['canRegister'] as bool,
        blockedReason: c['blockedReason'] as String?,
        plannedMealId: c['plannedMealId'] as String?,
        coveredItemCount: (c['coveredItemCount'] as num?)?.toInt() ?? 0,
        uncoveredItemCount: (c['uncoveredItemCount'] as num?)?.toInt() ?? 0,
        uncoveredPlannedItemIds: [
          for (final id in c['uncoveredPlannedItemIds'] as List<dynamic>? ?? [])
            id as String,
        ],
        executions: executions[type] ?? const [],
        suggestedTime: suggestedTime?.call(type),
      );
    }(),
];

DayExecution parseExecution(Map<String, dynamic> data) {
  final items = (data['items'] as List<dynamic>).map(_object).toList();
  return DayExecution(
    id: data['id'] as String,
    version: (data['version'] as num).toInt(),
    mealType: data['mealType'] as String,
    time: _hhmm(data['time'] as String?),
    itemCount: items.length,
    withSubstitution: items.any((i) => i['allowedSubstitutionId'] != null),
  );
}

/// `calendar-periods`: `plans`, `prescriptions` (com `start`/`end`) e
/// `freeExecutionDates`.
CalendarPeriods parseCalendar(Map<String, dynamic> data) {
  List<DatePeriod> periods(Object? raw) => [
    for (final item in raw as List<dynamic>? ?? const [])
      DatePeriod(
        start: _date(_object(item)['start'] as String),
        end: _object(item)['end'] == null
            ? null
            : _date(_object(item)['end'] as String),
      ),
  ];
  return CalendarPeriods(
    plans: periods(data['plans']),
    prescriptions: periods(data['prescriptions']),
    freeExecutionDates: [
      for (final d in data['freeExecutionDates'] as List<dynamic>? ?? const [])
        _date(d as String),
    ],
  );
}

DailySummary parseSummary(Map<String, dynamic> data) {
  Map<String, NutrientAmount> totals(Object? raw) => {
    for (final e in (raw as Map<String, dynamic>? ?? const {}).entries)
      e.key: NutrientAmount(
        _amount(_object(e.value)['amount']),
        (_object(e.value)['unit'] as String?) ?? '',
      ),
  };
  return DailySummary(
    prescribed: totals(data['prescribed']),
    planned: totals(data['planned']),
    realized: totals(data['realized']),
  );
}

String formatCivilDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime _date(String value) => civilDay(DateTime.parse(value));

String? _hhmm(String? time) =>
    time == null || time.length < 5 ? null : time.substring(0, 5);

num _amount(Object? value) =>
    value is num ? value : num.tryParse('$value') ?? 0;

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const FormatException('Resposta inválida.');
}

String _newKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
