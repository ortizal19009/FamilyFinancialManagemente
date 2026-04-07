import '../../../core/app_services.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/local_cache_storage.dart';
import '../../../core/offline/offline_operation.dart';

class FamilyRepository {
  FamilyRepository({
    ApiClient? apiClient,
    LocalCacheStorage? cacheStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _cacheStorage = cacheStorage ?? LocalCacheStorage();

  final ApiClient _apiClient;
  final LocalCacheStorage _cacheStorage;
  static const _membersCacheKey = 'mobile_family_members_cache';

  Future<List<Map<String, dynamic>>> loadMembers() async {
    try {
      final response = await _apiClient.get('/family/');
      final members =
          (response as List<dynamic>).map((item) => Map<String, dynamic>.from(item as Map)).toList();
      final pending = await _loadPendingLocalMembers();
      final merged = [...pending, ...members];
      await _cacheStorage.saveCollection(_membersCacheKey, merged);
      return merged;
    } catch (_) {
      return _cacheStorage.getCollection(_membersCacheKey);
    }
  }

  Future<void> createMember({
    required String name,
    required String relationship,
    String? linkedUserEmail,
  }) async {
    final localMember = {
      'id': _nextLocalId(),
      'name': name,
      'relationship': relationship,
      'linked_user_email': linkedUserEmail,
    };
    final cached = await _cacheStorage.getCollection(_membersCacheKey);
    await _cacheStorage.saveCollection(_membersCacheKey, [localMember, ...cached]);
    await AppServices.syncService.enqueue(
      OfflineOperation(
        id: 'family-${localMember['id']}',
        module: 'family',
        method: 'POST',
        path: '/family/',
        payload: {
          'name': name,
          'relationship': relationship,
          'linked_user_email': linkedUserEmail,
        },
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadPendingLocalMembers() async {
    final cached = await _cacheStorage.getCollection(_membersCacheKey);
    return cached.where((item) => (item['id'] as int? ?? 0) < 0).toList();
  }

  int _nextLocalId() => -DateTime.now().microsecondsSinceEpoch;

  Future<void> updateMember({
    required int id,
    required String name,
    required String relationship,
    String? linkedUserEmail,
  }) async {
    if (id < 0) {
      final cached = await _cacheStorage.getCollection(_membersCacheKey);
      final updated = cached
          .map((item) => item['id'] == id
              ? {
                  ...item,
                  'name': name,
                  'relationship': relationship,
                  'linked_user_email': linkedUserEmail,
                }
              : item)
          .toList();
      await _cacheStorage.saveCollection(_membersCacheKey, updated);
      return;
    }
    await _apiClient.put('/family/$id', {
      'name': name,
      'relationship': relationship,
      'linked_user_email': linkedUserEmail,
    });
  }

  Future<void> deleteMember(int id) async {
    if (id < 0) {
      final cached = await _cacheStorage.getCollection(_membersCacheKey);
      await _cacheStorage.saveCollection(
        _membersCacheKey,
        cached.where((item) => item['id'] != id).toList(),
      );
      return;
    }
    await _apiClient.delete('/family/$id');
  }
}
