import '../../../core/network/api_client.dart';
import '../../../core/offline/local_cache_storage.dart';
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

  Future<(List<DebtorSummary>, bool)> loadDebtors() async {
    try {
      final response = await _apiClient.get('/debtors/');
      final debtors = (response as List<dynamic>)
          .map((item) => DebtorSummary.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();

      await _cacheStorage.saveCollection(
        _debtorsCacheKey,
        debtors.map((item) => item.toMap()).toList(),
      );
      return (debtors, false);
    } catch (_) {
      final cached = await _cacheStorage.getCollection(_debtorsCacheKey);
      return (cached.map(DebtorSummary.fromMap).toList(), true);
    }
  }

  Future<void> createDebtor({
    required String name,
    required double amountOwed,
    String? description,
    String? dueDate,
    String status = 'pendiente',
  }) async {
    await _apiClient.post('/debtors/', {
      'name': name,
      'amount_owed': amountOwed,
      'description': description,
      'due_date': dueDate,
      'status': status,
    });
  }

  Future<void> updateDebtor({
    required int id,
    required String name,
    required double amountOwed,
    String? description,
    String? dueDate,
    required String status,
  }) async {
    await _apiClient.put('/debtors/$id', {
      'name': name,
      'amount_owed': amountOwed,
      'description': description,
      'due_date': dueDate,
      'status': status,
    });
  }

  Future<void> deleteDebtor(int id) async {
    await _apiClient.delete('/debtors/$id');
  }
}
