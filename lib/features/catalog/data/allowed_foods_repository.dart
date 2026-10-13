import '../domain/catalog_repository.dart';

/// Catalog view limited to a fixed set of foods (e.g. the substitutions a
/// nutritionist allowed for a planned item). Always a single page.
class AllowedFoodsRepository implements CatalogRepository {
  const AllowedFoodsRepository(this._base, this._ids);

  final CatalogRepository _base;
  final List<String> _ids;

  @override
  Future<CatalogPage> list(int page, {String? query}) async {
    if (page > 0) return const CatalogPage(foods: [], totalPages: 1);
    final details = await Future.wait(_ids.map(_base.get));
    // The allowed set is small and complete, so filtering locally is exact.
    final term = _fold(query ?? '');
    return CatalogPage(
      foods: [
        for (final d in details)
          if (_fold(d.food.name).contains(term)) d.food,
      ],
      totalPages: 1,
    );
  }

  static String _fold(String text) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    return text.trim().toLowerCase().split('').map((c) {
      final i = from.indexOf(c);
      return i < 0 ? c : to[i];
    }).join();
  }

  @override
  Future<FoodDetails> get(String id) => _base.get(id);
}
