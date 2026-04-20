import '../../../core/app_services.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/local_cache_storage.dart';
import '../../../core/offline/offline_operation.dart';
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
  static const _accountsCacheKey = 'mobile_bank_accounts_cache';

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
      final pendingAssets = await _loadPendingLocalAssets();
      final pendingIncome = await _loadPendingLocalIncome();
      final mergedAssets = [...pendingAssets, ...assets];
      final mergedIncome = [...pendingIncome, ...income];

      await _cacheStorage.saveCollection(
        _assetsCacheKey,
        mergedAssets.map((item) => item.toMap()).toList(),
      );
      await _cacheStorage.saveCollection(
        _incomeCacheKey,
        mergedIncome.map((item) => item.toMap()).toList(),
      );

      return AssetsSnapshot(
        assets: mergedAssets,
        income: mergedIncome,
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
    final localAsset = AssetSummary(
      id: _nextLocalId(),
      name: name,
      value: value,
      owner: owner,
      description: description,
      purchaseDate: purchaseDate,
    );
    final cached = await _cacheStorage.getCollection(_assetsCacheKey);
    await _cacheStorage.saveCollection(_assetsCacheKey, [localAsset.toMap(), ...cached]);
    await AppServices.syncService.enqueue(OfflineOperation(
      id: 'asset-${localAsset.id}',
      module: 'assets',
      method: 'POST',
      path: '/assets_income/assets',
      payload: {
        'name': name,
        'value': value,
        'owner': owner,
        'description': description,
        'purchase_date': purchaseDate,
      },
      createdAt: DateTime.now(),
    ));
  }

  Future<List<AssetSummary>> _loadPendingLocalAssets() async {
    final cached = await _cacheStorage.getCollection(_assetsCacheKey);
    return cached.map(AssetSummary.fromMap).where((item) => item.id < 0).toList();
  }

  Future<List<IncomeSummary>> _loadPendingLocalIncome() async {
    final cached = await _cacheStorage.getCollection(_incomeCacheKey);
    return cached.map(IncomeSummary.fromMap).where((item) => item.id < 0).toList();
  }

  int _nextLocalId() => -DateTime.now().microsecondsSinceEpoch;

  Future<void> updateAsset({
    required int id,
    required String name,
    required double value,
    String? owner,
    String? description,
    String? purchaseDate,
  }) async {
    final cached = await _cacheStorage.getCollection(_assetsCacheKey);
    final updated = cached
        .map((item) => item['id'] == id
            ? {
                ...item,
                'name': name,
                'value': value,
                'owner': owner,
                'description': description,
                'purchase_date': purchaseDate,
              }
            : item)
        .toList();
    await _cacheStorage.saveCollection(_assetsCacheKey, updated);

    if (id < 0) {
      await AppServices.syncService.enqueue(OfflineOperation(
        id: 'asset-$id',
        module: 'assets',
        method: 'POST',
        path: '/assets_income/assets',
        payload: {
          'name': name,
          'value': value,
          'owner': owner,
          'description': description,
          'purchase_date': purchaseDate,
        },
        createdAt: DateTime.now(),
      ));
      return;
    }

    await AppServices.syncService.enqueue(OfflineOperation(
      id: 'asset-update-$id',
      module: 'assets',
      method: 'PUT',
      path: '/assets_income/assets/$id',
      payload: {
        'name': name,
        'value': value,
        'owner': owner,
        'description': description,
        'purchase_date': purchaseDate,
      },
      createdAt: DateTime.now(),
    ));
  }

  Future<void> deleteAsset(int id) async {
    final cached = await _cacheStorage.getCollection(_assetsCacheKey);
    await _cacheStorage.saveCollection(
      _assetsCacheKey,
      cached.where((item) => item['id'] != id).toList(),
    );

    if (id < 0) {
      await AppServices.syncService.removeQueuedOperation('asset-$id');
      return;
    }
    await AppServices.syncService.removeQueuedOperation('asset-update-$id');
    await AppServices.syncService.enqueue(OfflineOperation(
      id: 'asset-delete-$id',
      module: 'assets',
      method: 'DELETE',
      path: '/assets_income/assets/$id',
      payload: const {},
      createdAt: DateTime.now(),
    ));
  }

  Future<void> createIncome({
    required double amount,
    required String source,
    required String incomeDate,
    required String destinationType,
    int? bankAccountId,
    String? bankAccountName,
    String? description,
  }) async {
    if (destinationType == 'bank_account' && bankAccountId == null) {
      throw Exception('Selecciona una cuenta para este ingreso');
    }
    final localIncome = IncomeSummary(
      id: _nextLocalId(),
      userName: null,
      amount: amount,
      source: source,
      incomeDate: incomeDate,
      destinationType: destinationType,
      bankAccountId: bankAccountId,
      bankAccountName: bankAccountName,
      description: description,
    );
    final cached = await _cacheStorage.getCollection(_incomeCacheKey);
    await _cacheStorage.saveCollection(_incomeCacheKey, [localIncome.toMap(), ...cached]);
    await AppServices.syncService.enqueue(OfflineOperation(
      id: 'income-${localIncome.id}',
      module: 'assets',
      method: 'POST',
      path: '/assets_income/income',
      payload: {
        'amount': amount,
        'source': source,
        'income_date': incomeDate,
        'destination_type': destinationType,
        'bank_account_id': bankAccountId,
        'description': description,
      },
      createdAt: DateTime.now(),
    ));
    await _applyLocalIncomeEffect(
      destinationType: destinationType,
      amount: amount,
      bankAccountId: bankAccountId,
      sign: 1,
    );
  }

  Future<void> updateIncome({
    required int id,
    required double amount,
    required String source,
    required String incomeDate,
    required String destinationType,
    int? bankAccountId,
    String? bankAccountName,
    String? description,
  }) async {
    final cached = await _cacheStorage.getCollection(_incomeCacheKey);
    final previous = cached.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['id'] == id,
          orElse: () => null,
        );
    if (previous != null) {
      await _applyLocalIncomeEffect(
        destinationType: previous['destination_type'] as String? ?? 'cash',
        amount: (previous['amount'] as num?)?.toDouble() ?? 0,
        bankAccountId: previous['bank_account_id'] as int?,
        sign: -1,
      );
    }
    final updated = cached
        .map((item) => item['id'] == id
            ? {
                ...item,
                'amount': amount,
                'source': source,
                'income_date': incomeDate,
                'destination_type': destinationType,
                'bank_account_id': bankAccountId,
                'bank_account_name': bankAccountName,
                'description': description,
              }
            : item)
        .toList();
    await _cacheStorage.saveCollection(_incomeCacheKey, updated);
    await _applyLocalIncomeEffect(
      destinationType: destinationType,
      amount: amount,
      bankAccountId: bankAccountId,
      sign: 1,
    );

    if (id < 0) {
      await AppServices.syncService.enqueue(OfflineOperation(
        id: 'income-$id',
        module: 'assets',
        method: 'POST',
        path: '/assets_income/income',
        payload: {
          'amount': amount,
          'source': source,
          'income_date': incomeDate,
          'destination_type': destinationType,
          'bank_account_id': bankAccountId,
          'description': description,
        },
        createdAt: DateTime.now(),
      ));
      return;
    }

    await AppServices.syncService.enqueue(OfflineOperation(
      id: 'income-update-$id',
      module: 'assets',
      method: 'PUT',
      path: '/assets_income/income/$id',
      payload: {
        'amount': amount,
        'source': source,
        'income_date': incomeDate,
        'destination_type': destinationType,
        'bank_account_id': bankAccountId,
        'description': description,
      },
      createdAt: DateTime.now(),
    ));
  }

  Future<void> deleteIncome(int id) async {
    final cached = await _cacheStorage.getCollection(_incomeCacheKey);
    final previous = cached.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['id'] == id,
          orElse: () => null,
        );
    if (previous != null) {
      await _applyLocalIncomeEffect(
        destinationType: previous['destination_type'] as String? ?? 'cash',
        amount: (previous['amount'] as num?)?.toDouble() ?? 0,
        bankAccountId: previous['bank_account_id'] as int?,
        sign: -1,
      );
    }
    await _cacheStorage.saveCollection(
      _incomeCacheKey,
      cached.where((item) => item['id'] != id).toList(),
    );

    if (id < 0) {
      await AppServices.syncService.removeQueuedOperation('income-$id');
      return;
    }
    await AppServices.syncService.removeQueuedOperation('income-update-$id');
    await AppServices.syncService.enqueue(OfflineOperation(
      id: 'income-delete-$id',
      module: 'assets',
      method: 'DELETE',
      path: '/assets_income/income/$id',
      payload: const {},
      createdAt: DateTime.now(),
    ));
  }

  Future<void> _applyLocalIncomeEffect({
    required String destinationType,
    required double amount,
    int? bankAccountId,
    required int sign,
  }) async {
    if (destinationType != 'bank_account' || bankAccountId == null) {
      return;
    }

    final cachedAccounts = await _cacheStorage.getCollection(_accountsCacheKey);
    final updatedAccounts = cachedAccounts
        .map((item) => item['id'] == bankAccountId
            ? {
                ...item,
                'current_balance': ((item['current_balance'] as num?)?.toDouble() ?? 0) + (amount * sign),
              }
            : item)
        .toList();
    await _cacheStorage.saveCollection(_accountsCacheKey, updatedAccounts);
  }
}
