import '../../../core/network/api_client.dart';

class FamilyRepository {
  FamilyRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> loadMembers() async {
    final response = await _apiClient.get('/family/');
    return (response as List<dynamic>).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> createMember({
    required String name,
    required String relationship,
  }) async {
    await _apiClient.post('/family/', {
      'name': name,
      'relationship': relationship,
    });
  }

  Future<void> updateMember({
    required int id,
    required String name,
    required String relationship,
  }) async {
    await _apiClient.put('/family/$id', {
      'name': name,
      'relationship': relationship,
    });
  }

  Future<void> deleteMember(int id) async {
    await _apiClient.delete('/family/$id');
  }
}
