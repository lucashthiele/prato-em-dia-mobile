import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/catalog_repository.dart';
import '../catalog_labels.dart';
import '../cubit/catalog_cubit.dart';
import 'food_details_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({required this.repository, super.key});

  final CatalogRepository repository;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final CatalogCubit _cubit;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _cubit = CatalogCubit(widget.repository)..load();
    _scroll.addListener(_nearBottom);
  }

  void _nearBottom() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 300) {
      _cubit.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _cubit.close();
    super.dispose();
  }

  Future<void> _open(FoodSummary food) async {
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            FoodDetailsScreen(food: food, repository: widget.repository),
      ),
    );
    if (removed == true) await _cubit.load();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: Scaffold(
      appBar: AppBar(title: const Text('Catálogo')),
      body: SafeArea(
        child: BlocBuilder<CatalogCubit, CatalogState>(
          builder: (context, state) {
            if (!state.loaded && state.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!state.loaded && state.error != null) {
              return _CenteredMessage(
                icon: Icons.wifi_off_outlined,
                message: state.error!,
                onRetry: _cubit.load,
              );
            }
            if (state.loaded && state.foods.isEmpty && !state.loading) {
              return _CenteredMessage(
                icon: Icons.inventory_2_outlined,
                message: 'Nenhum alimento disponível no catálogo.',
                onRetry: _cubit.load,
              );
            }
            return RefreshIndicator(
              onRefresh: _cubit.load,
              child: ListView.builder(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: state.foods.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.loading) const LinearProgressIndicator(),
                        if (state.error != null)
                          _InlineError(
                            message: state.error!,
                            onRetry: _cubit.load,
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 4, 16),
                          child: Text(
                            'Alimentos e informações nutricionais',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    );
                  }
                  final food = state.foods[index - 1];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      title: Text(food.name),
                      subtitle: Text(
                        [
                          if (food.brand != null) food.brand!,
                          if (food.category != null) food.category!,
                          originLabel(food.origin, food.source),
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(food),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BlocBuilder<CatalogCubit, CatalogState>(
        builder: (context, state) {
          if (state.loadingMore) {
            return const SafeArea(child: LinearProgressIndicator());
          }
          if (state.moreError != null) {
            return SafeArea(
              child: _InlineError(
                message: state.moreError!,
                onRetry: _cubit.retryMore,
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    ),
  );
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Expanded(child: Text(message)),
        TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
      ],
    ),
  );
}
