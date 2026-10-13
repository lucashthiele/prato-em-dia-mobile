import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/catalog_repository.dart';
import '../catalog_labels.dart';
import '../cubit/catalog_cubit.dart';
import 'food_details_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    required this.repository,
    this.selecting = false,
    super.key,
  });

  final CatalogRepository repository;

  /// When true, tapping a food pops it as the result instead of opening its
  /// details, so the screen can be used as a food picker.
  final bool selecting;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final CatalogCubit _cubit;
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

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
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    _cubit.close();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _cubit.search(text),
    );
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    _cubit.search('');
  }

  Future<void> _open(FoodSummary food) async {
    if (widget.selecting) {
      Navigator.of(context).pop(food);
      return;
    }
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
      appBar: AppBar(
        title: Text(widget.selecting ? 'Escolher alimento' : 'Alimentos'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                controller: _search,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: (text) {
                  _debounce?.cancel();
                  _cubit.search(text);
                },
                decoration: InputDecoration(
                  hintText: 'Buscar alimento',
                  prefixIcon: const Icon(Icons.search_rounded),
                  // Always present (only disabled when empty) so typing the
                  // first character does not change the field's structure.
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _search,
                    builder: (context, value, _) => IconButton(
                      tooltip: 'Limpar busca',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: value.text.isEmpty ? null : _clearSearch,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
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
                      message: state.query.isEmpty
                          ? 'Nenhum alimento disponível no catálogo.'
                          : 'Nenhum alimento encontrado para “${state.query}”.',
                      onRetry: _cubit.load,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _cubit.load,
                    child: ListView.builder(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                      itemCount: state.foods.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (state.loading)
                                const LinearProgressIndicator(),
                              if (state.error != null)
                                _InlineError(
                                  message: state.error!,
                                  onRetry: _cubit.load,
                                ),
                              Text(
                                'Catálogo de alimentos',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Consulte porções e informações nutricionais.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 22),
                            ],
                          );
                        }
                        final food = state.foods[index - 1];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 7,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                child: const Icon(
                                  Icons.restaurant_menu_rounded,
                                ),
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
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
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
