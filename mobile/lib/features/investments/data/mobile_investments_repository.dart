import '../../../core/network/api_client.dart';
import '../../../core/offline/local_cache_storage.dart';
import '../domain/investment_summary.dart';

class MobileInvestmentsRepository {
  MobileInvestmentsRepository({
    ApiClient? apiClient,
    LocalCacheStorage? cacheStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _cacheStorage = cacheStorage ?? LocalCacheStorage();

  final ApiClient _apiClient;
  final LocalCacheStorage _cacheStorage;

  static const _investmentsCacheKey = 'mobile_investments_cache';

  Future<List<InvestmentSummary>> loadInvestments() async {
    try {
      final response = await _apiClient.get('/investments/');
      final investments = (response as List<dynamic>)
          .map((item) => InvestmentSummary.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
      await _cacheStorage.saveCollection(
        _investmentsCacheKey,
        investments.map((item) => item.toMap()).toList(),
      );
      return investments;
    } catch (_) {
      final cached = await _cacheStorage.getCollection(_investmentsCacheKey);
      return cached.map(InvestmentSummary.fromMap).toList();
    }
  }

  Future<void> createInvestment({
    required String institution,
    required String investmentType,
    required String title,
    String? owner,
    required double investedAmount,
    required double currentValue,
    double? expectedReturnRate,
    String? startDate,
    String? endDate,
    required String status,
    String? notes,
  }) async {
    await _apiClient.post('/investments/', {
      'institution': institution,
      'investment_type': investmentType,
      'title': title,
      'owner': owner,
      'invested_amount': investedAmount,
      'current_value': currentValue,
      'expected_return_rate': expectedReturnRate,
      'start_date': startDate,
      'end_date': endDate,
      'status': status,
      'notes': notes,
    });
  }

  Future<void> updateInvestment({
    required int id,
    required String institution,
    required String investmentType,
    required String title,
    String? owner,
    required double investedAmount,
    required double currentValue,
    double? expectedReturnRate,
    String? startDate,
    String? endDate,
    required String status,
    String? notes,
  }) async {
    await _apiClient.put('/investments/$id', {
      'institution': institution,
      'investment_type': investmentType,
      'title': title,
      'owner': owner,
      'invested_amount': investedAmount,
      'current_value': currentValue,
      'expected_return_rate': expectedReturnRate,
      'start_date': startDate,
      'end_date': endDate,
      'status': status,
      'notes': notes,
    });
  }

  Future<void> deleteInvestment(int id) async {
    await _apiClient.delete('/investments/$id');
  }
}
