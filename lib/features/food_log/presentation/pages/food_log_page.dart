import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_environment.dart';
import '../../../../core/formatting/decimal.dart';
import '../../../../core/nutrition/macros.dart';
import '../../../auth/domain/auth_session.dart';
import '../../../catalog/data/allowed_foods_repository.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_repository_impl.dart';
import '../../../catalog/domain/catalog_repository.dart';
import '../../../catalog/presentation/pages/catalog_screen.dart';

enum _Mode { restricted, substitutionsOnly, free }

class _Portion {
  const _Portion(
    this.id,
    this.label,
    this.unit, [
    this.macros = const {},
    this.quantity,
  ]);
  final String id, label;
  final String? unit;
  // Size of one portion in [unit]; the server scales nutrients by
  // quantity × multiplier ÷ this value.
  final num? quantity;
  // Per-portion amounts by macro key (see _macroKeys); absent when the catalog
  // has no numeric value for it.
  final Map<String, num> macros;
  num? get kcal => macros['kcal'];
}

Map<String, num> _macros(Map<String, dynamic>? nutrients) {
  final result = <String, num>{};
  for (final macro in macroAliases.keys) {
    // Only numeric values count; trace/unavailable entries are skipped.
    final byCode = {
      for (final e in (nutrients ?? const <String, dynamic>{}).entries)
        if (e.value is Map<String, dynamic> &&
            (e.value as Map<String, dynamic>)['status'] == 'VALUE' &&
            _num((e.value as Map<String, dynamic>)['amount']) != null)
          e.key: _num((e.value as Map<String, dynamic>)['amount'])!,
    };
    final amount = pickMacro(byCode, macro);
    if (amount != null) result[macro] = amount;
  }
  return result;
}

class _Food {
  const _Food(this.id, this.name, this.portions);
  final String id, name;
  final List<_Portion> portions;
}

class _Item {
  const _Item({
    required this.id,
    required this.food,
    required this.quantity,
    required this.originalQuantity,
    this.portion,
    this.plannedId,
    this.allowedId,
    this.alternatives = const [],
    this.planFood,
    this.planPortion,
  });
  final String id;
  final _Food food;
  final _Portion? portion;
  final num quantity;
  final num originalQuantity;
  final String? plannedId, allowedId;
  final List<_Item> alternatives;
  // What the nutritionist originally planned, kept so a substituted item can
  // always be switched back.
  final _Food? planFood;
  final _Portion? planPortion;
  bool get removed => plannedId != null && quantity == 0;
  // The backend requires an active catalog portion for every submitted line,
  // including a planned line whose declared consumption is zero.
  bool get complete => portion != null && (removed || quantity > 0);
  _Item copy({
    _Food? food,
    _Portion? portion,
    num? quantity,
    String? allowedId,
    bool clearAllowed = false,
  }) => _Item(
    id: id,
    food: food ?? this.food,
    portion: portion ?? this.portion,
    quantity: quantity ?? this.quantity,
    originalQuantity: originalQuantity,
    plannedId: plannedId,
    allowedId: clearAllowed ? null : allowedId ?? this.allowedId,
    alternatives: alternatives,
    planFood: planFood,
    planPortion: planPortion,
  );
}

class FoodLogPage extends StatefulWidget {
  const FoodLogPage({
    required this.mealId,
    required this.mealName,
    required this.date,
    required this.session,
    required this.renewSession,
    this.mealType,
    this.plannedTime,
    this.dio,
    super.key,
  });

  /// Civil date (`yyyy-MM-dd`) of the planned meal; executions are dated.
  final String mealId, mealName, date;

  /// Category (`BREAKFAST`, `LUNCH`, `SNACK`, `DINNER`) and planned `HH:mm`
  /// time of the meal, when the caller knows them.
  final String? mealType, plannedTime;
  final AuthSession session;
  final Future<AuthSession?> Function() renewSession;
  final Dio? dio;
  @override
  State<FoodLogPage> createState() => _State();
}

class _State extends State<FoodLogPage> {
  late final Dio dio =
      widget.dio ??
      Dio(
        BaseOptions(
          baseUrl: AppEnvironment.apiBaseUrl,
          headers: const {'Accept': 'application/json'},
        ),
      );
  late AuthSession session = widget.session;
  String key = _key();
  String? lastBody;
  // Active execution of this meal, when one was already saved.
  Map<String, dynamic>? execution;
  _Mode? mode;
  // Time of the execution as `HH:mm`: the saved one, else the planned one,
  // else the current time.
  late String time;
  List<_Item>? items;
  String? error;
  bool saving = false;
  Future<T> auth<T>(Future<T> Function(String) f) async {
    try {
      return await f('${session.tokenType} ${session.accessToken}');
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) rethrow;
      final n = await widget.renewSession();
      if (n == null) rethrow;
      session = n;
      return f('${n.tokenType} ${n.accessToken}');
    }
  }

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    time =
        _hhmm(widget.plannedTime) ??
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    load();
  }

  Future<_Food> food(String id) async {
    final r = await auth(
      (a) => dio.get<Map<String, dynamic>>(
        '/api/v1/foods/$id',
        options: Options(headers: {'Authorization': a}),
      ),
    );
    final d = r.data!;
    return _Food(
      d['id'] as String,
      d['name'] as String,
      (d['portions'] as List).map((x) {
        final p = x as Map<String, dynamic>;
        return _Portion(
          p['id'] as String,
          p['label'] as String,
          p['unit'] as String?,
          _macros(p['nutrients'] as Map<String, dynamic>?),
          _num(p['quantity']),
        );
      }).toList(),
    );
  }

  Future<_Item> item(Map<String, dynamic> d, {String? allowed}) async {
    final f = await food(d['catalogFoodId'] as String);
    final part = d['catalogPortionId'];
    final alts = <_Item>[];
    for (final x in (d['allowedSubstitutions'] as List? ?? const [])) {
      final a = x as Map<String, dynamic>;
      alts.add(await item(a, allowed: a['allowedSubstitutionId'] as String?));
    }
    final planned = part == null
        ? null
        : f.portions.where((p) => p.id == part).firstOrNull;
    final portions = _portionCount(d, planned);
    return _Item(
      id: '${d['plannedItemId'] ?? f.id}-$allowed',
      food: f,
      portion: part == null
          ? null
          : f.portions.where((p) => p.id == part).firstOrNull,
      quantity: portions,
      originalQuantity: portions,
      plannedId: d['plannedItemId'] as String?,
      allowedId: allowed,
      alternatives: alts,
      planFood: f,
      planPortion: part == null
          ? null
          : f.portions.where((p) => p.id == part).firstOrNull,
    );
  }

  Future<_Item> recordedItem(
    Map<String, dynamic> snapshot,
    _Item? planned,
    int index,
  ) async {
    final foodId = snapshot['foodId'] as String;
    final f = planned?.food.id == foodId ? planned!.food : await food(foodId);
    final portionId = snapshot['portionId'] as String?;
    final unit = snapshot['unit'] as String?;
    final portion =
        f.portions.where((p) => p.id == portionId).firstOrNull ??
        (portionId == null
            ? null
            : _Portion(portionId, unit ?? 'Porção registrada', unit));
    return _Item(
      id: planned?.id ?? 'recorded-$index',
      food: f,
      portion: portion,
      quantity: _portionCount(snapshot, portion),
      originalQuantity: planned?.originalQuantity ?? 0,
      plannedId: planned?.plannedId,
      allowedId: snapshot['allowedSubstitutionId'] as String?,
      alternatives: planned?.alternatives ?? const [],
      planFood: planned?.planFood,
      planPortion: planned?.planPortion,
    );
  }

  Future<List<_Item>> latestItems(List<_Item> planned) async {
    final response = await auth(
      (a) => dio.get<List<dynamic>>(
        '/api/v1/patients/me/meal-executions',
        queryParameters: {'date': widget.date},
        options: Options(headers: {'Authorization': a}),
      ),
    );
    final current = response.data!
        .cast<Map<String, dynamic>>()
        .where((e) => e['plannedMealId'] == widget.mealId)
        .firstOrNull;
    execution = current;
    if (current == null) return planned;
    time = _hhmm(current['time'] as String?) ?? time;
    final consumed = (current['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final byPlannedId = {
      for (final x in consumed)
        if (x['plannedItemId'] != null) x['plannedItemId'] as String: x,
    };
    final result = <_Item>[];
    for (final x in planned) {
      final snapshot = byPlannedId[x.plannedId];
      // A planned item missing from the saved execution was not consumed.
      result.add(
        snapshot == null
            ? x.copy(quantity: 0)
            : await recordedItem(snapshot, x, result.length),
      );
    }
    for (final x in consumed) {
      if (x['plannedItemId'] == null) {
        result.add(await recordedItem(x, null, result.length));
      }
    }
    return result;
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final r = await auth(
        (a) => dio.get<Map<String, dynamic>>(
          '/api/v1/planned-meals/${widget.mealId}/food-log',
          options: Options(headers: {'Authorization': a}),
        ),
      );
      final d = r.data!;
      final list = <_Item>[];
      for (final x in d['items'] as List) {
        list.add(await item(x as Map<String, dynamic>));
      }
      final currentItems = await latestItems(list);
      if (mounted) {
        setState(() {
          mode = switch (d['mode']) {
            'RESTRICTED' => _Mode.restricted,
            'SUBSTITUTIONS_ONLY' => _Mode.substitutionsOnly,
            'FREE' => _Mode.free,
            _ => throw const FormatException('Modo de registro inválido.'),
          };
          items = currentItems;
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() => error = _message(e));
    } on FormatException {
      if (mounted) {
        setState(() => error = 'Não foi possível ler o registro da refeição.');
      }
    } on TypeError {
      if (mounted) {
        setState(() => error = 'Não foi possível ler o registro da refeição.');
      }
    }
  }

  void replace(int i, _Item x) => setState(
    () => items = [
      for (var n = 0; n < items!.length; n++)
        if (n == i) x else items![n],
    ],
  );
  Future<void> edit(int i) async {
    final x = items![i];
    final y = await Navigator.of(context).push<_Item>(
      MaterialPageRoute(
        builder: (sheet) => _Editor(
          item: x.removed ? x.copy(quantity: x.originalQuantity) : x,
          onSwap: mode == _Mode.restricted
              ? null
              : () {
                  Navigator.pop(sheet);
                  mode == _Mode.free ? swapFree(i) : swapAllowed(i);
                },
          onRemove: mode == _Mode.free && !x.removed
              ? () {
                  Navigator.pop(sheet);
                  remove(i);
                }
              : null,
        ),
      ),
    );
    if (y != null) replace(i, y);
  }

  void remove(int i) {
    final x = items![i];
    if (x.plannedId == null) {
      setState(() => items = items!.where((v) => v.id != x.id).toList());
    } else {
      replace(i, x.copy(quantity: x.removed ? x.originalQuantity : 0));
    }
  }

  late final CatalogRepository catalog = CatalogRepositoryImpl(
    CatalogApi(dio, session, widget.renewSession),
  );

  Future<_Food?> pick(CatalogRepository repository) async {
    final chosen = await Navigator.of(context).push<FoodSummary>(
      MaterialPageRoute(
        builder: (_) => CatalogScreen(repository: repository, selecting: true),
      ),
    );
    if (chosen == null || !mounted) return null;
    try {
      return await food(chosen.id);
    } on DioException catch (e) {
      _snack(_message(e));
    } on TypeError {
      _snack('Não foi possível abrir este alimento.');
    }
    return null;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Free mode: any catalog food, planned line is zeroed and a new one added.
  Future<void> swapFree(int i) async {
    final f = await pick(catalog);
    if (f == null || !mounted) return;
    final y = await Navigator.of(context).push<_Item>(
      MaterialPageRoute(
        builder: (_) => _Editor(
          item: _Item(
            id: 'new-${_key()}',
            food: f,
            quantity: 0,
            originalQuantity: 0,
          ),
        ),
      ),
    );
    if (y != null && mounted) {
      setState(() {
        replace(i, items![i].copy(quantity: 0));
        items = [...items!, y];
      });
    }
  }

  /// Substitutions-only mode: same catalog screen, listing only allowed foods.
  Future<void> swapAllowed(int i) async {
    final x = items![i];
    final options = <String, _Item>{
      if (x.planFood != null)
        x.planFood!.id: x.copy(
          food: x.planFood,
          portion: x.planPortion,
          clearAllowed: true,
        ),
      for (final a in x.alternatives)
        a.food.id: x.copy(
          food: a.food,
          portion: a.portion,
          allowedId: a.allowedId,
          clearAllowed: a.allowedId == null,
        ),
    };
    final f = await pick(
      AllowedFoodsRepository(catalog, options.keys.toList()),
    );
    final chosen = f == null ? null : options[f.id];
    if (chosen == null || !mounted) return;
    replace(i, chosen);
    await edit(i);
  }

  Future<void> add() async {
    final f = await pick(catalog);
    if (f == null || !mounted) return;
    final y = await Navigator.of(context).push<_Item>(
      MaterialPageRoute(
        builder: (_) => _Editor(
          item: _Item(
            id: 'new-${_key()}',
            food: f,
            quantity: 0,
            originalQuantity: 0,
          ),
        ),
      ),
    );
    if (y != null && mounted) setState(() => items = [...items!, y]);
  }

  Future<void> pickTime() async {
    final parts = time.split(':');
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
      helpText: 'Hora da refeição',
    );
    if (chosen == null || !mounted) return;
    setState(
      () => time =
          '${chosen.hour.toString().padLeft(2, '0')}:${chosen.minute.toString().padLeft(2, '0')}',
    );
  }

  Future<void> save() async {
    if (items!.any((x) => !x.complete)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe porção e quantidade em cada alimento.'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final body = <String, dynamic>{
        'date': widget.date,
        'plannedMealId': widget.mealId,
        'time': time,
        if (widget.mealType != null) 'mealType': widget.mealType,
        'items': [
          for (final x in items!.where((x) => !x.removed))
            {
              'foodId': x.food.id,
              'portionId': x.portion!.id,
              if (x.portion?.unit != null) 'unit': x.portion!.unit,
              // The server scales by quantity × multiplier ÷ portion size, so
              // send one portion's size and the number of portions as multiplier.
              'quantity': x.portion!.quantity ?? 1,
              'multiplier': x.quantity,
              if (x.plannedId != null) 'plannedItemId': x.plannedId,
              if (mode == _Mode.substitutionsOnly && x.allowedId != null)
                'allowedSubstitutionId': x.allowedId,
            },
        ],
      };
      // Same intention (retry after an uncertain failure) keeps the key.
      final encoded = jsonEncode(body);
      if (encoded != lastBody) key = _key();
      lastBody = encoded;
      final current = execution;
      await auth(
        (a) => current == null
            ? dio.post(
                '/api/v1/patients/me/meal-executions',
                data: body,
                options: Options(
                  headers: {'Authorization': a, 'Idempotency-Key': key},
                ),
              )
            : dio.put(
                '/api/v1/patients/me/meal-executions/${current['id']}',
                data: body,
                options: Options(
                  headers: {
                    'Authorization': a,
                    'If-Match': current['version'],
                    'Idempotency-Key': key,
                  },
                ),
              ),
      );
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(e))));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    if (items == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Registrar consumo')),
        body: Center(
          child: error == null
              ? const CircularProgressIndicator()
              : OutlinedButton(onPressed: load, child: Text(error!)),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhe da refeição')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Refeição planejada',
                    style: Theme.of(c).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(c).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.mealName,
                    style: Theme.of(c).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(c).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          '${_fmt(items!.fold<num>(0, (sum, x) => sum + (x.portion?.kcal ?? 0) * x.quantity))} kcal',
                          style: Theme.of(c).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  OutlinedButton.icon(
                    onPressed: saving ? null : pickTime,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text('Hora: $time'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ALIMENTOS',
                    style: Theme.of(c).textTheme.titleMedium?.copyWith(
                      color: Theme.of(c).colorScheme.onSurfaceVariant,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: items!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final x = items![i];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 5,
                      ),
                      leading: Icon(
                        x.removed
                            ? Icons.remove_circle_outline_rounded
                            : Icons.restaurant_outlined,
                        color: x.removed
                            ? Theme.of(c).colorScheme.onSurfaceVariant
                            : Theme.of(c).colorScheme.primary,
                      ),
                      title: Text(x.food.name),
                      subtitle: Text(
                        x.removed
                            ? 'Não consumido'
                            : x.portion == null
                            ? 'Escolha uma porção'
                            : '${_fmt(x.quantity)} × ${x.portion!.label}${x.portion!.kcal == null ? '' : ' · ${_fmt(x.portion!.kcal! * x.quantity)} kcal'}',
                      ),
                      onTap: () => edit(i),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  );
                },
              ),
            ),
            if (mode == _Mode.free)
              Padding(
                padding: const EdgeInsets.all(20),
                child: OutlinedButton.icon(
                  onPressed: saving ? null : add,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar alimento do catálogo'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Registrando…' : 'Confirmar consumo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _macroRows = [
  ('kcal', 'Energia', 'kcal'),
  ('protein', 'Proteínas', 'g'),
  ('carbs', 'Carboidratos', 'g'),
  ('fat', 'Gorduras', 'g'),
  ('fiber', 'Fibras', 'g'),
];

class _Editor extends StatefulWidget {
  const _Editor({required this.item, this.onSwap, this.onRemove});
  final _Item item;
  final VoidCallback? onSwap, onRemove;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late _Food f = widget.item.food;
  late _Portion? p = widget.item.portion;
  late final q = TextEditingController(text: _fmt(widget.item.quantity))
    ..addListener(() => setState(() {}));
  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final theme = Theme.of(c);
    final qty = parseDecimal(q.text) ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar alimento')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(f.name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 20),
            DropdownButtonFormField<_Portion>(
              initialValue: p,
              decoration: const InputDecoration(labelText: 'Porção ou unidade'),
              items: f.portions
                  .map((x) => DropdownMenuItem(value: x, child: Text(x.label)))
                  .toList(),
              onChanged: (x) => setState(() => p = x),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: q,
              inputFormatters: const [DecimalInputFormatter()],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Número de porções',
                helperText: p?.quantity == null || p?.unit == null
                    ? null
                    : '= ${_fmt(qty * p!.quantity!)} ${p!.unit}',
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'MACROS',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final (key, label, unit) in _macroRows)
                    ListTile(
                      title: Text(label),
                      trailing: Text(
                        p?.macros[key] == null
                            ? 'não disponível'
                            : '${formatDecimal(p!.macros[key]! * qty, maxDecimals: 1)} $unit',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                final n = parseDecimal(q.text);
                if (n == null || n <= 0 || p == null) return;
                Navigator.pop(
                  c,
                  widget.item.copy(food: f, portion: p, quantity: n),
                );
              },
              child: const Text('Aplicar'),
            ),
            if (widget.onSwap != null)
              TextButton.icon(
                onPressed: widget.onSwap,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Trocar alimento'),
              ),
            if (widget.onRemove != null)
              TextButton(
                onPressed: widget.onRemove,
                child: const Text('Remover'),
              ),
          ],
        ),
      ),
    );
  }
}

/// `HH:mm` of a server time such as `13:30:00`; null when absent.
String? _hhmm(String? v) =>
    v == null || v.length < 5 ? null : v.substring(0, 5);

num? _num(Object? v) => v is num
    ? v
    : v is String
    ? num.tryParse(v)
    : null;
String _fmt(num n) => formatDecimal(n);

/// Number of portions of a stored/planned line: quantity × multiplier ÷ the
/// portion's own size (the same scaling the server applies to nutrients).
num _portionCount(Map<String, dynamic> d, _Portion? portion) {
  final base = (_num(d['quantity']) ?? 0) * (_num(d['multiplier']) ?? 1);
  final size = portion?.quantity;
  return size == null || size == 0 ? base : base / size;
}

String _message(DioException e) => e.response?.statusCode == 409
    ? 'O planejamento mudou. Atualize antes de confirmar.'
    : 'Não foi possível concluir o registro.';
String _key() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
