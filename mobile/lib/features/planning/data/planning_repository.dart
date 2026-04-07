import '../../../core/network/api_client.dart';
import '../../expenses/domain/expense_category.dart';

class PlanningRepository {
  PlanningRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> loadPlanning({
    required int month,
    required int year,
  }) async {
    final response = await _apiClient.get('/planning/?month=$month&year=$year');
    return (response as List<dynamic>).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<List<ExpenseCategory>> loadCategories() async {
    final response = await _apiClient.get('/expenses/categories');
    return (response as List<dynamic>)
        .map((item) => ExpenseCategory.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> createPlan({
    required int categoryId,
    required double plannedAmount,
    required int month,
    required int year,
  }) async {
    await _apiClient.post('/planning/', {
      'category_id': categoryId,
      'planned_amount': plannedAmount,
      'month': month,
      'year': year,
    });
  }

  Future<void> updatePlan({
    required int id,
    required int categoryId,
    required double plannedAmount,
    required int month,
    required int year,
  }) async {
    await _apiClient.put('/planning/$id', {
      'category_id': categoryId,
      'planned_amount': plannedAmount,
      'month': month,
      'year': year,
    });
  }

  Future<void> deletePlan(int id) async {
    await _apiClient.delete('/planning/$id');
  }
}
