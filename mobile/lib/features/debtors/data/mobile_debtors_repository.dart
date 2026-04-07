import '../../../core/app_services.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/local_cache_storage.dart';
import '../../../core/offline/offline_operation.dart';
import '../domain/debtor_models.dart';

class MobileDebtorsRepository {
  MobileDebtorsRepository({
    ApiClient? apiClient,
    LocalCacheStorage? cacheStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _cacheStorage = cacheStorage ?? LocalCacheStorage();

  final ApiClient _apiClient;
  final LocalCacheStorage _cacheStorage;

  static const _debtorsCacheKey = 'mobile_debtors_cache';
  static const _smallDebtsCacheKey = 'mobile_small_debts_cache';

  Future<(List<DebtorSummary>, List<SmallDebtSummary>, bool)> loadDebtors() async {
    try {
      final response = await _apiClient.get('/debtors/');
      final smallDebtsResponse = await _apiClient.get('/debtors/small-debts');
      final debtors = (response as List<dynamic>)
          .map((item) => DebtorSummary.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
      final smallDebts = (smallDebtsResponse as List<dynamic>)
          .map((item) => SmallDebtSummary.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
      final pendingDebtors = await _loadPendingLocalDebtors();
      final pendingSmallDebts = await _loadPendingLocalSmallDebts();
      final mergedDebtors = [...pendingDebtors, ...debtors];
      final mergedSmallDebts = [...pendingSmallDebts, ...smallDebts];

      await _cacheStorage.saveCollection(
        _debtorsCacheKey,
        mergedDebtors.map((item) => item.toMap()).toList(),
      );
      await _cacheStorage.saveCollection(
        _smallDebtsCacheKey,
        mergedSmallDebts.map((item) => item.toMap()).toList(),
      );
      return (mergedDebtors, mergedSmallDebts, false);
    } catch (_) {
      final cached = await _cacheStorage.getCollection(_debtorsCacheKey);
      final cachedSmallDebts = await _cacheStorage.getCollection(_smallDebtsCacheKey);
      return (
        cached.map(DebtorSummary.fromMap).toList(),
        cachedSmallDebts.map(SmallDebtSummary.fromMap).toList(),
        true,
      );
    }
  }

  Future<void> createDebtor({
    required String name,
    required double amountOwed,
    String? description,
    String? dueDate,
    String status = 'pendiente',
  }) async {
    final localDebtor = DebtorSummary(
      id: _nextLocalId(),
      name: name,
      amountOwed: amountOwed,
      description: description,
      dueDate: dueDate,
      status: status,
    );
    final cached = await _cacheStorage.getCollection(_debtorsCacheKey);
    await _cacheStorage.saveCollection(_debtorsCacheKey, [localDebtor.toMap(), ...cached]);
    await AppServices.syncService.enqueue(OfflineOperation(
      id: 'debtor-${localDebtor.id}',
      module: 'debtors',
      method: 'POST',
      path: '/debtors/',
      payload: {
        'name': name,
        'amount_owed': amountOwed,
        'description': description,
        'due_date': dueDate,
        'status': status,
      },
      createdAt: DateTime.now(),
    ));
  }

  Future<List<DebtorSummary>> _loadPendingLocalDebtors() async {
    final cached = await _cacheStorage.getCollection(_debtorsCacheKey);
    return cached.map(DebtorSummary.fromMap).where((item) => item.id < 0).toList();
  }

  Future<List<SmallDebtSummary>> _loadPendingLocalSmallDebts() async {
    final cached = await _cacheStorage.getCollection(_smallDebtsCacheKey);
    return cached.map(SmallDebtSummary.fromMap).where((item) => item.id < 0).toList();
  }

  int _nextLocalId() => -DateTime.now().microsecondsSinceEpoch;

  Future<void> updateDebtor({
    required int id,
    required String name,
    required double amountOwed,
    String? description,
    String? dueDate,
    required String status,
  }) async {
    if (id < 0) {
      final cached = await _cacheStorage.getCollection(_debtorsCacheKey);
      final updated = cached
          .map((item) => item['id'] == id
              ? {
                  ...item,
                  'name': name,
                  'amount_owed': amountOwed,
                  'description': description,
                  'due_date': dueDate,
                  'status': status,
                }
              : item)
          .toList();
      await _cacheStorage.saveCollection(_debtorsCacheKey, updated);
      return;
    }
    await _apiClient.put('/debtors/$id', {
      'name': name,
      'amount_owed': amountOwed,
      'description': description,
      'due_date': dueDate,
      'status': status,
    });
  }

  Future<void> deleteDebtor(int id) async {
    if (id < 0) {
      final cached = await _cacheStorage.getCollection(_debtorsCacheKey);
      await _cacheStorage.saveCollection(
        _debtorsCacheKey,
        cached.where((item) => item['id'] != id).toList(),
      );
      return;
    }
    await _apiClient.delete('/debtors/$id');
  }

  Future<void> createSmallDebt({
    required String lenderName,
    required double amount,
    String? description,
    String? borrowedDate,
    String? dueDate,
    String status = 'pendiente',
  }) async {
    final localDebt = SmallDebtSummary(
      id: _nextLocalId(),
      lenderName: lenderName,
      amount: amount,
      description: description,
      borrowedDate: borrowedDate,
      dueDate: dueDate,
      status: status,
    );
    final cached = await _cacheStorage.getCollection(_smallDebtsCacheKey);
    await _cacheStorage.saveCollection(_smallDebtsCacheKey, [localDebt.toMap(), ...cached]);
    await AppServices.syncService.enqueue(OfflineOperation(
      id: 'small-debt-${localDebt.id}',
      module: 'debtors',
      method: 'POST',
      path: '/debtors/small-debts',
      payload: {
        'lender_name': lenderName,
        'amount': amount,
        'description': description,
        'borrowed_date': borrowedDate,
        'due_date': dueDate,
        'status': status,
      },
      createdAt: DateTime.now(),
    ));
  }

  Future<void> updateSmallDebt({
    required int id,
    required String lenderName,
    required double amount,
    String? description,
    String? borrowedDate,
    String? dueDate,
    required String status,
  }) async {
    if (id < 0) {
      final cached = await _cacheStorage.getCollection(_smallDebtsCacheKey);
      final updated = cached
          .map((item) => item['id'] == id
              ? {
                  ...item,
                  'lender_name': lenderName,
                  'amount': amount,
                  'description': description,
                  'borrowed_date': borrowedDate,
                  'due_date': dueDate,
                  'status': status,
                }
              : item)
          .toList();
      await _cacheStorage.saveCollection(_smallDebtsCacheKey, updated);
      return;
    }
    await _apiClient.put('/debtors/small-debts/$id', {
      'lender_name': lenderName,
      'amount': amount,
      'description': description,
      'borrowed_date': borrowedDate,
      'due_date': dueDate,
      'status': status,
    });
  }

  Future<void> deleteSmallDebt(int id) async {
    if (id < 0) {
      final cached = await _cacheStorage.getCollection(_smallDebtsCacheKey);
      await _cacheStorage.saveCollection(
        _smallDebtsCacheKey,
        cached.where((item) => item['id'] != id).toList(),
      );
      return;
    }
    await _apiClient.delete('/debtors/small-debts/$id');
  }
}
