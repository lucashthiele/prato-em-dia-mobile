import 'package:flutter/material.dart';

import '../../domain/catalog_repository.dart';
import '../catalog_labels.dart';

class FoodDetailsScreen extends StatefulWidget {
  const FoodDetailsScreen({
    required this.food,
    required this.repository,
    super.key,
  });

  final FoodSummary food;
  final CatalogRepository repository;

  @override
  State<FoodDetailsScreen> createState() => _FoodDetailsScreenState();
}

class _FoodDetailsScreenState extends State<FoodDetailsScreen> {
  FoodDetails? _details;
  String? _error;
  bool _loading = true;
  bool _removed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = await widget.repository.get(widget.food.id);
      if (!mounted) return;
      setState(() => _details = details);
    } on CatalogFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _removed = error.notFound;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do alimento')),
      body: _loading && details == null
          ? Center(
              child: Semantics(
                label: 'Carregando detalhes do alimento',
                child: CircularProgressIndicator(),
              ),
            )
          : _error != null && details == null
          ? _DetailsError(
              message: _error!,
              removed: _removed,
              onRetry: _load,
              onBack: () => Navigator.of(context).pop(_removed),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _FoodHeader(food: details!.food),
                  if (details.notes != null) ...[
                    const SizedBox(height: 20),
                    _InfoSection(label: 'Observações', value: details.notes!),
                  ],
                  if (details.preparationMethod != null) ...[
                    const SizedBox(height: 16),
                    _InfoSection(
                      label: 'Modo de preparo',
                      value: details.preparationMethod!,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Porções',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (details.portions.isEmpty)
                    const _NoPortions()
                  else
                    for (final portion in details.portions) ...[
                      _PortionCard(portion: portion),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
    );
  }
}

class _FoodHeader extends StatelessWidget {
  const _FoodHeader({required this.food});
  final FoodSummary food;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(food.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        if (food.brand != null) Text(food.brand!),
        if (food.category != null) Text('Categoria: ${food.category}'),
        Text(originLabel(food.origin, food.source)),
      ],
    ),
  );
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(value),
    ],
  );
}

class _NoPortions extends StatelessWidget {
  const _NoPortions();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text('Este alimento ainda não possui porções disponíveis.'),
    ),
  );
}

class _PortionCard extends StatelessWidget {
  const _PortionCard({required this.portion});
  final FoodPortion portion;

  @override
  Widget build(BuildContext context) {
    final measure = _measureLabel(portion);
    return Semantics(
      container: true,
      label: 'Porção $measure',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                portion.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text('Medida: $measure'),
              Text('Equivalente: ${_gramsLabel(portion.gramsEquivalent)}'),
              const SizedBox(height: 16),
              Text('Nutrientes', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              if (portion.nutrients.isEmpty)
                const Text('Informações nutricionais não disponíveis.')
              else
                for (final entry in portion.nutrients.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${nutrientLabel(entry.key)}: ${nutrientValueLabel(entry.value)}',
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsError extends StatelessWidget {
  const _DetailsError({
    required this.message,
    required this.removed,
    required this.onRetry,
    required this.onBack,
  });
  final String message;
  final bool removed;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (removed)
            FilledButton(
              onPressed: onBack,
              child: const Text('Voltar ao catálogo'),
            )
          else
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
        ],
      ),
    ),
  );
}

String _measureLabel(FoodPortion portion) {
  final pieces = <String>[
    if (portion.quantity != null) portion.quantity!,
    if (portion.unit != null) portion.unit!,
  ];
  return pieces.isEmpty ? 'não disponível' : pieces.join(' ');
}

String _gramsLabel(String? grams) =>
    grams == null ? 'não disponível' : '$grams g';
