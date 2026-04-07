import '../../../core/network/api_client.dart';
import '../../../core/offline/local_cache_storage.dart';

class DashboardRepository {
  DashboardRepository({
    ApiClient? apiClient,
    LocalCacheStorage? cacheStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _cacheStorage = cacheStorage ?? LocalCacheStorage();

  final ApiClient _apiClient;
  final LocalCacheStorage _cacheStorage;
  static const _summaryCacheKey = 'mobile_dashboard_summary_cache';

  Future<Map<String, dynamic>> loadSummary() async {
    try {
      final response = await _apiClient.get('/dashboard/summary');
      final summary = Map<String, dynamic>.from(response as Map);
      await _cacheStorage.saveCollection(_summaryCacheKey, [summary]);
      return summary;
    } catch (_) {
      final cached = await _cacheStorage.getCollection(_summaryCacheKey);
      if (cached.isNotEmpty) {
        return cached.first;
      }
      rethrow;
    }
  }
}
