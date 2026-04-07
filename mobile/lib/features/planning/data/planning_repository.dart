import '../../../core/app_services.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/local_cache_storage.dart';
import '../../../core/offline/offline_operation.dart';
import '../../expenses/domain/expense_category.dart';

class PlanningRepository {
  PlanningRepository({
    ApiClient? apiClient,
    LocalCacheStorage? cacheStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _cacheStorage = cacheStorage ?? LocalCacheStorage();

  final ApiClient _apiClient;
  final LocalCacheStorage _cacheStorage;
  static const _planningCategoriesCacheKey = 'mobile_planning_categories_cache';

  Future<List<Map<String, dynamic>>> loadPlanning({
    required int month,
    required int year,
  }) async {
    final cacheKey = 'mobile_planning_${year}_$month';
    try {
      final response = await _apiClient.get('/planning/?month=$month&year=$year');
      final plans =
          (response as List<dynamic>).map((item) => Map<String, dynamic>.from(item as Map)).toList();
      final pending = await _loadPendingLocalPlans(cacheKey);
      final merged = [...pending, ...plans];
      await _cacheStorage.saveCollection(cacheKey, merged);
      return merged;
    } catch (_) {
      return _cacheStorage.getCollection(cacheKey);
    }
  }

  Future<List<ExpenseCategory>> loadCategories() async {
    try {
      final response = await _apiClient.get('/expenses/categories');
      final categories = (response as List<dynamic>)
          .map((item) => ExpenseCategory.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
      await _cacheStorage.saveCollection(
        _planningCategoriesCacheKey,
        categories.map((item) => item.toMap()).toList(),
      );
      return categories;
    } catch (_) {
      final cached = await _cacheStorage.getCollection(_planningCategoriesCacheKey);
      return cached.map(ExpenseCategory.fromMap).toList();
    }
  }

  Future<void> createPlan({
    required int categoryId,
    required double plannedAmount,
    required int month,
    required int year,
  }) async {
    final categories = await _cacheStorage.getCollection(_planningCategoriesCacheKey);
    final matchedCategory = categories.firstWhere(
      (item) => item['id'] == categoryId,
      orElse: () => <String, dynamic>{},
    );
    final cacheKey = 'mobile_planning_${year}_$month';
    final localPlan = {
      'id': _nextLocalId(),
      'category_id': categoryId,
      'category_name': matchedCategory['name'] as String? ?? '',
      'planned_amount': plannedAmount,
      'actual_amount': 0.0,
      'month': month,
      'year': year,
    };
    final cached = await _cacheStorage.getCollection(cacheKey);
    await _cacheStorage.saveCollection(cacheKey, [localPlan, ...cached]);
    await AppServices.syncService.enqueue(OfflineOperation(
      id: 'plan-${localPlan['id']}',
      module: 'planning',
      method: 'POST',
      path: '/planning/',
      payload: {
        'category_id': categoryId,
        'planned_amount': plannedAmount,
        'month': month,
        'year': year,
      },
      createdAt: DateTime.now(),
    ));
  }

  Future<List<Map<String, dynamic>>> _loadPendingLocalPlans(String cacheKey) async {
    final cached = await _cacheStorage.getCollection(cacheKey);
    return cached.where((item) => (item['id'] as int? ?? 0) < 0).toList();
  }

  int _nextLocalId() => -DateTime.now().microsecondsSinceEpoch;

  Future<void> updatePlan({
    required int id,
    required int categoryId,
    required double plannedAmount,
    required int month,
    required int year,
  }) async {
    final cacheKey = 'mobile_planning_${year}_$month';
    if (id < 0) {
      final categories = await _cacheStorage.getCollection(_planningCategoriesCacheKey);
      final matchedCategory = categories.firstWhere(
        (item) => item['id'] == categoryId,
        orElse: () => <String, dynamic>{},
      );
      final cached = await _cacheStorage.getCollection(cacheKey);
      final updated = cached
          .map((item) => item['id'] == id
              ? {
                  ...item,
                  'category_id': categoryId,
                  'category_name': matchedCategory['name'] as String? ?? '',
                  'planned_amount': plannedAmount,
                  'month': month,
                  'year': year,
                }
              : item)
          .toList();
      await _cacheStorage.saveCollection(cacheKey, updated);
      return;
    }
    await _apiClient.put('/planning/$id', {
      'category_id': categoryId,
      'planned_amount': plannedAmount,
      'month': month,
      'year': year,
    });
  }

  Future<void> deletePlan(int id) async {
    if (id < 0) {
      return;
    }
    await _apiClient.delete('/planning/$id');
  }
}
