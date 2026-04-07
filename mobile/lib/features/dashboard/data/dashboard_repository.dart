import '../../../core/network/api_client.dart';

class DashboardRepository {
  DashboardRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> loadSummary() async {
    final response = await _apiClient.get('/dashboard/summary');
    return Map<String, dynamic>.from(response as Map);
  }
}
