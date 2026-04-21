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

  Map<String, dynamic> _memberPayload({
    required String name,
    required String relationship,
    String? linkedUserEmail,
    String? password,
  }) {
    return {
      'name': name,
      'relationship': relationship,
      'linked_user_email': linkedUserEmail,
      'password': password,
    };
  }

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

  Future<Map<String, dynamic>> createMember({
    required String name,
    required String relationship,
    String? linkedUserEmail,
    String? password,
  }) async {
    final payload = _memberPayload(
      name: name,
      relationship: relationship,
      linkedUserEmail: linkedUserEmail,
      password: password,
    );

    if (AppServices.syncService.status.isOnline) {
      final response = await _apiClient.post('/family/', payload);
      return Map<String, dynamic>.from(response as Map);
    }

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
        payload: payload,
        createdAt: DateTime.now(),
      ),
    );
    return {
      'queued': true,
    };
  }

  Future<List<Map<String, dynamic>>> _loadPendingLocalMembers() async {
    final cached = await _cacheStorage.getCollection(_membersCacheKey);
    return cached.where((item) => (item['id'] as int? ?? 0) < 0).toList();
  }

  int _nextLocalId() => -DateTime.now().microsecondsSinceEpoch;

  Future<Map<String, dynamic>> updateMember({
    required int id,
    required String name,
    required String relationship,
    String? linkedUserEmail,
    String? password,
  }) async {
    final payload = _memberPayload(
      name: name,
      relationship: relationship,
      linkedUserEmail: linkedUserEmail,
      password: password,
    );

    if (id >= 0 && AppServices.syncService.status.isOnline) {
      final response = await _apiClient.put('/family/$id', payload);
      return Map<String, dynamic>.from(response as Map);
    }

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

    if (id < 0) {
      await AppServices.syncService.enqueue(
        OfflineOperation(
          id: 'family-$id',
          module: 'family',
          method: 'POST',
          path: '/family/',
          payload: payload,
          createdAt: DateTime.now(),
        ),
      );
      return {
        'queued': true,
      };
    }
    await AppServices.syncService.enqueue(
      OfflineOperation(
        id: 'family-update-$id',
        module: 'family',
        method: 'PUT',
        path: '/family/$id',
        payload: payload,
        createdAt: DateTime.now(),
      ),
    );
    return {
      'queued': true,
    };
  }

  Future<void> deleteMember(int id) async {
    final cached = await _cacheStorage.getCollection(_membersCacheKey);
    await _cacheStorage.saveCollection(
      _membersCacheKey,
      cached.where((item) => item['id'] != id).toList(),
    );

    if (id < 0) {
      await AppServices.syncService.removeQueuedOperation('family-$id');
      return;
    }
    await AppServices.syncService.removeQueuedOperation('family-update-$id');
    await AppServices.syncService.enqueue(
      OfflineOperation(
        id: 'family-delete-$id',
        module: 'family',
        method: 'DELETE',
        path: '/family/$id',
        payload: const {},
        createdAt: DateTime.now(),
      ),
    );
  }
}
