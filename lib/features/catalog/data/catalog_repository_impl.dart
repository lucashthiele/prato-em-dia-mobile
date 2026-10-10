import 'package:dio/dio.dart';

import '../domain/catalog_repository.dart';
import 'catalog_api.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  const CatalogRepositoryImpl(this._api);

  final CatalogRemoteDataSource _api;

  @override
  Future<CatalogPage> list(int page) => _run(() async {
    final data = await _api.list(page);
    final content = _array(data['content']);
    final totalPages = data['totalPages'];
    if (totalPages is! int || totalPages < 0) {
      throw const FormatException('Paginação inválida.');
    }
    return CatalogPage(
      foods: content.map((value) => _food(_object(value))).toList(),
      totalPages: totalPages,
    );
  });

  @override
  Future<FoodDetails> get(String id) => _run(() async {
    final data = await _api.get(id);
    return FoodDetails(
      food: _food(data),
      notes: _optional(data['notes']),
      preparationMethod: _optional(data['preparationMethod']),
      portions: _array(data['portions'])
          .map((value) => _portion(_object(value)))
          .toList(),
    );
  });

  Future<T> _run<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401) {
        throw const CatalogFailure('Sua sessão terminou. Entre novamente.');
      }
      if (status == 403) {
        throw const CatalogFailure('Você não tem acesso ao catálogo.');
      }
      if (status == 404) {
        throw const CatalogFailure(
          'Este alimento não está mais disponível. Atualize o catálogo.',
          notFound: true,
        );
      }
      if (status != null && status >= 500) {
        throw const CatalogFailure(
          'O serviço está indisponível. Tente novamente em instantes.',
        );
      }
      throw const CatalogFailure(
        'Não foi possível conectar. Verifique sua internet e tente novamente.',
      );
    } on FormatException {
      throw const CatalogFailure(
        'Não foi possível ler o catálogo. Tente novamente.',
      );
    } on TypeError {
      throw const CatalogFailure(
        'Não foi possível ler o catálogo. Tente novamente.',
      );
    }
  }
}

FoodSummary _food(Map<String, dynamic> data) => FoodSummary(
  id: _string(data['id']),
  name: _string(data['name']),
  origin: _string(data['origin']),
  brand: _optional(data['brand']),
  category: _optional(data['category']),
  source: _optional(data['source']),
);

FoodPortion _portion(Map<String, dynamic> data) {
  final rawNutrients = _nullableObject(data['nutrients']);
  return FoodPortion(
    id: _string(data['id']),
    label: _string(data['label']),
    quantity: _decimal(data['quantity']),
    unit: _optional(data['unit']),
    gramsEquivalent: _decimal(data['gramsEquivalent']),
    nutrients: rawNutrients.map((key, value) {
      final nutrient = _object(value);
      return MapEntry(
        key,
        Nutrient(
          status: _optional(nutrient['status']) ?? 'NOT_AVAILABLE',
          unit: _optional(nutrient['unit']) ?? '',
          amount: _decimal(nutrient['amount']),
          rawValue: _optional(nutrient['rawValue']),
        ),
      );
    }),
  );
}

Map<String, dynamic> _object(Object? value) => value is Map<String, dynamic>
    ? value
    : throw const FormatException('Objeto inválido.');

Map<String, dynamic> _nullableObject(Object? value) =>
    value == null ? const {} : _object(value);

List<dynamic> _array(Object? value) => value is List<dynamic>
    ? value
    : throw const FormatException('Lista inválida.');

String _string(Object? value) =>
    value is String ? value : throw const FormatException('Texto inválido.');

String? _optional(Object? value) => value == null
    ? null
    : value is String
    ? value.trim().isEmpty
          ? null
          : value
    : throw const FormatException('Texto inválido.');

String? _decimal(Object? value) => value == null
    ? null
    : value is num || value is String
    ? value.toString()
    : throw const FormatException('Número inválido.');
