import '../../../core/network/api_client.dart';
import '../../../core/offline/local_cache_storage.dart';
import '../domain/assets_models.dart';

class MobileAssetsRepository {
  MobileAssetsRepository({
    ApiClient? apiClient,
    LocalCacheStorage? cacheStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _cacheStorage = cacheStorage ?? LocalCacheStorage();

  final ApiClient _apiClient;
  final LocalCacheStorage _cacheStorage;

  static const _assetsCacheKey = 'mobile_assets_cache';
  static const _incomeCacheKey = 'mobile_income_cache';

  Future<AssetsSnapshot> loadSnapshot() async {
    try {
      final assetsResponse = await _apiClient.get('/assets_income/assets');
      final incomeResponse = await _apiClient.get('/assets_income/income');

      final assets = (assetsResponse as List<dynamic>)
          .map((item) => AssetSummary.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
      final income = (incomeResponse as List<dynamic>)
          .map((item) => IncomeSummary.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();

      await _cacheStorage.saveCollection(
        _assetsCacheKey,
        assets.map((item) => item.toMap()).toList(),
      );
      await _cacheStorage.saveCollection(
        _incomeCacheKey,
        income.map((item) => item.toMap()).toList(),
      );

      return AssetsSnapshot(
        assets: assets,
        income: income,
        loadedFromCache: false,
      );
    } catch (_) {
      final assetsCache = await _cacheStorage.getCollection(_assetsCacheKey);
      final incomeCache = await _cacheStorage.getCollection(_incomeCacheKey);
      return AssetsSnapshot(
        assets: assetsCache.map(AssetSummary.fromMap).toList(),
        income: incomeCache.map(IncomeSummary.fromMap).toList(),
        loadedFromCache: true,
      );
    }
  }

  Future<void> createAsset({
    required String name,
    required double value,
    String? owner,
    String? description,
    String? purchaseDate,
  }) async {
    await _apiClient.post('/assets_income/assets', {
      'name': name,
      'value': value,
      'owner': owner,
      'description': description,
      'purchase_date': purchaseDate,
    });
  }

  Future<void> updateAsset({
    required int id,
    required String name,
    required double value,
    String? owner,
    String? description,
    String? purchaseDate,
  }) async {
    await _apiClient.put('/assets_income/assets/$id', {
      'name': name,
      'value': value,
      'owner': owner,
      'description': description,
      'purchase_date': purchaseDate,
    });
  }

  Future<void> deleteAsset(int id) async {
    await _apiClient.delete('/assets_income/assets/$id');
  }

  Future<void> createIncome({
    required double amount,
    required String source,
    required String incomeDate,
    String? description,
  }) async {
    await _apiClient.post('/assets_income/income', {
      'amount': amount,
      'source': source,
      'income_date': incomeDate,
      'description': description,
    });
  }

  Future<void> updateIncome({
    required int id,
    required double amount,
    required String source,
    required String incomeDate,
    String? description,
  }) async {
    await _apiClient.put('/assets_income/income/$id', {
      'amount': amount,
      'source': source,
      'income_date': incomeDate,
      'description': description,
    });
  }

  Future<void> deleteIncome(int id) async {
    await _apiClient.delete('/assets_income/income/$id');
  }
}
