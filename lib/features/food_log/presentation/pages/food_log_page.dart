import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_environment.dart';
import '../../../auth/domain/auth_session.dart';

enum _Mode { restricted, substitutionsOnly, free }

class _Portion {
  const _Portion(this.id, this.label, this.unit, this.kcal);
  final String id, label;
  final String? unit;
  final num? kcal;
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
  });
  final String id;
  final _Food food;
  final _Portion? portion;
  final num quantity;
  final num originalQuantity;
  final String? plannedId, allowedId;
  final List<_Item> alternatives;
  bool get removed => plannedId != null && quantity == 0;
  // The backend requires an active catalog portion for every submitted line,
  // including a planned line whose declared consumption is zero.
  bool get complete => portion != null && (removed || quantity > 0);
  _Item copy({
    _Food? food,
    _Portion? portion,
    num? quantity,
    String? allowedId,
  }) => _Item(
    id: id,
    food: food ?? this.food,
    portion: portion ?? this.portion,
    quantity: quantity ?? this.quantity,
    originalQuantity: originalQuantity,
    plannedId: plannedId,
    allowedId: allowedId ?? this.allowedId,
    alternatives: alternatives,
  );
}

class FoodLogPage extends StatefulWidget {
  const FoodLogPage({
    required this.mealId,
    required this.mealName,
    required this.session,
    required this.renewSession,
    super.key,
  });
  final String mealId, mealName;
  final AuthSession session;
  final Future<AuthSession?> Function() renewSession;
  @override
  State<FoodLogPage> createState() => _State();
}

class _State extends State<FoodLogPage> {
  late final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppEnvironment.apiBaseUrl,
      headers: const {'Accept': 'application/json'},
    ),
  );
  late AuthSession session = widget.session;
  late final key = _key();
  _Mode? mode;
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
        final n = p['nutrients'] as Map<String, dynamic>?;
        final cal = n?['CAL'] as Map<String, dynamic>?;
        return _Portion(
          p['id'] as String,
          p['label'] as String,
          p['unit'] as String?,
          _num(cal?['amount']),
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
    return _Item(
      id: '${d['plannedItemId'] ?? f.id}-$allowed',
      food: f,
      portion: part == null
          ? null
          : f.portions.where((p) => p.id == part).firstOrNull,
      quantity: _num(d['quantity']) ?? 0,
      originalQuantity: _num(d['quantity']) ?? 0,
      plannedId: d['plannedItemId'] as String?,
      allowedId: allowed,
      alternatives: alts,
    );
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
      if (mounted)
        setState(() {
          mode = switch (d['mode']) {
            'RESTRICTED' => _Mode.restricted,
            'SUBSTITUTIONS_ONLY' => _Mode.substitutionsOnly,
            'FREE' => _Mode.free,
            _ => throw const FormatException('Modo de registro inválido.'),
          };
          items = list;
        });
    } on DioException catch (e) {
      if (mounted) setState(() => error = _message(e));
    } on FormatException {
      if (mounted) {
        setState(() => error = 'O modo de registro informado é inválido.');
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
    if (x.removed) return;
    final y = await showModalBottomSheet<_Item>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _Editor(item: x, canChangeFood: mode == _Mode.substitutionsOnly),
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

  Future<void> add({int? replaceIndex}) async {
    final f = await pick();
    if (f == null) return;
    final y = await showModalBottomSheet<_Item>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _Editor(
        item: _Item(
          id: 'new-${_key()}',
          food: f,
          quantity: 0,
          originalQuantity: 0,
        ),
        canChangeFood: false,
      ),
    );
    if (y != null && mounted)
      setState(() {
        if (replaceIndex != null)
          replace(replaceIndex, items![replaceIndex].copy(quantity: 0));
        items = [...items!, y];
      });
  }

  Future<_Food?> pick() => showModalBottomSheet<_Food>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _Picker(
      load: food,
      page: (p) async {
        final r = await auth(
          (a) => dio.get<Map<String, dynamic>>(
            '/api/v1/foods',
            queryParameters: {'page': p, 'size': 20},
            options: Options(headers: {'Authorization': a}),
          ),
        );
        return r.data!;
      },
    ),
  );
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
      await auth(
        (a) => dio.post(
          '/api/v1/planned-meals/${widget.mealId}/completion-events',
          data: {
            'occurredAt': DateTime.now().toUtc().toIso8601String(),
            'consumedItems': items!
                .map(
                  (x) => {
                    'catalogFoodId': x.food.id,
                    if (x.portion != null) 'catalogPortionId': x.portion!.id,
                    if (x.portion?.unit != null) 'unit': x.portion!.unit,
                    'quantity': x.quantity,
                    'multiplier': 1,
                    if (x.plannedId != null) 'plannedItemId': x.plannedId,
                    if (mode == _Mode.substitutionsOnly && x.allowedId != null)
                      'allowedSubstitutionId': x.allowedId,
                  },
                )
                .toList(),
          },
          options: Options(
            headers: {'Authorization': a, 'Idempotency-Key': key},
          ),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(e))));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    if (items == null)
      return Scaffold(
        appBar: AppBar(title: const Text('Registrar consumo')),
        body: Center(
          child: error == null
              ? const CircularProgressIndicator()
              : OutlinedButton(onPressed: load, child: Text(error!)),
        ),
      );
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar consumo')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.mealName,
                  style: Theme.of(c).textTheme.headlineSmall,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: items!.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final x = items![i];
                  return Card(
                    child: ListTile(
                      title: Text(x.food.name),
                      subtitle: Text(
                        x.removed
                            ? 'Não consumido'
                            : '${x.portion?.label ?? 'Escolha uma porção'} · Quantidade: ${_fmt(x.quantity)}${x.portion?.kcal == null ? '' : ' · ${_fmt(x.portion!.kcal! * x.quantity)} kcal'}',
                      ),
                      onTap: () => edit(i),
                      trailing: mode == _Mode.free
                          ? PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'remove')
                                  remove(i);
                                else
                                  add(replaceIndex: i);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'replace',
                                  child: Text('Trocar alimento'),
                                ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text(
                                    x.removed ? 'Desfazer remoção' : 'Remover',
                                  ),
                                ),
                              ],
                            )
                          : null,
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

class _Editor extends StatefulWidget {
  const _Editor({required this.item, required this.canChangeFood});
  final _Item item;
  final bool canChangeFood;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late _Food f = widget.item.food;
  late _Portion? p = widget.item.portion;
  late final q = TextEditingController(text: _fmt(widget.item.quantity));
  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final choices = [widget.item, ...widget.item.alternatives];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(c).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.canChangeFood && choices.length > 1)
            DropdownButtonFormField<_Item>(
              value: choices.where((x) => x.food.id == f.id).firstOrNull,
              items: choices
                  .map(
                    (x) => DropdownMenuItem(value: x, child: Text(x.food.name)),
                  )
                  .toList(),
              onChanged: (x) => setState(() {
                f = x!.food;
                p = x.portion;
              }),
            ),
          DropdownButtonFormField<_Portion>(
            value: p,
            decoration: const InputDecoration(labelText: 'Porção ou unidade'),
            items: f.portions
                .map((x) => DropdownMenuItem(value: x, child: Text(x.label)))
                .toList(),
            onChanged: (x) => setState(() => p = x),
          ),
          TextField(
            controller: q,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantidade'),
          ),
          FilledButton(
            onPressed: () {
              final n = _num(q.text.replaceAll(',', '.'));
              if (n == null || n <= 0 || p == null) return;
              final a = widget.item.alternatives
                  .where((x) => x.food.id == f.id)
                  .firstOrNull;
              Navigator.pop(
                c,
                widget.item.copy(
                  food: f,
                  portion: p,
                  quantity: n,
                  allowedId: a?.allowedId,
                ),
              );
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }
}

class _Picker extends StatefulWidget {
  const _Picker({required this.load, required this.page});
  final Future<_Food> Function(String) load;
  final Future<Map<String, dynamic>> Function(int) page;
  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  var page = 0, total = 1, loading = false;
  final foods = <Map<String, dynamic>>[];
  String? error;
  @override
  void initState() {
    super.initState();
    more();
  }

  Future<void> more() async {
    if (loading || page >= total) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final d = await widget.page(page);
      if (!mounted) return;
      setState(() {
        foods.addAll((d['content'] as List).cast<Map<String, dynamic>>());
        total = d['totalPages'] as int;
        page++;
      });
    } on DioException catch (exception) {
      if (mounted) setState(() => error = _message(exception));
    } on FormatException {
      if (mounted)
        setState(() => error = 'Não foi possível carregar o catálogo.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Adicionar alimento'),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView(
            children: [
              for (final x in foods)
                ListTile(
                  title: Text(x['name'] as String),
                  onTap: () async {
                    setState(() {
                      loading = true;
                      error = null;
                    });
                    try {
                      final f = await widget.load(x['id'] as String);
                      if (c.mounted) Navigator.pop(c, f);
                    } on DioException catch (exception) {
                      if (mounted) setState(() => error = _message(exception));
                    } on FormatException {
                      if (mounted)
                        setState(
                          () => error = 'Não foi possível abrir este alimento.',
                        );
                    } finally {
                      if (mounted) setState(() => loading = false);
                    }
                  },
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Text(error!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: more,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              if (page < total)
                OutlinedButton(
                  onPressed: loading ? null : more,
                  child: Text(loading ? 'Carregando…' : 'Carregar mais'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

num? _num(Object? v) => v is num
    ? v
    : v is String
    ? num.tryParse(v)
    : null;
String _fmt(num n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toString();
String _message(DioException e) => e.response?.statusCode == 409
    ? 'O planejamento mudou. Atualize antes de confirmar.'
    : 'Não foi possível concluir o registro.';
String _key() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
