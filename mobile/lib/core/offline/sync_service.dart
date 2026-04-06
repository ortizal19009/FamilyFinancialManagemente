import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import 'backend_reachability_service.dart';
import 'offline_operation.dart';
import 'offline_queue_storage.dart';
import 'sync_status.dart';

class SyncService extends ChangeNotifier {
  SyncService({
    ApiClient? apiClient,
    OfflineQueueStorage? queueStorage,
    BackendReachabilityService? reachabilityService,
  })  : _apiClient = apiClient ?? ApiClient(),
        _queueStorage = queueStorage ?? OfflineQueueStorage(),
        _reachabilityService = reachabilityService ?? BackendReachabilityService();

  final ApiClient _apiClient;
  final OfflineQueueStorage _queueStorage;
  final BackendReachabilityService _reachabilityService;

  SyncStatus _status = SyncStatus.initial();
  SyncStatus get status => _status;

  Future<void> initialize() async {
    final queue = await _queueStorage.getQueue();
    final online = await _reachabilityService.canReachBackend();
    _status = _status.copyWith(
      isOnline: online,
      pendingCount: queue.length,
    );
    notifyListeners();

    _reachabilityService.connectivityStream.listen((_) async {
      final canReach = await _reachabilityService.canReachBackend();
      _status = _status.copyWith(isOnline: canReach);
      notifyListeners();
      if (canReach) {
        await syncPendingOperations();
      }
    });
  }

  Future<void> enqueue(OfflineOperation operation) async {
    final queue = await _queueStorage.getQueue();
    queue.add(operation);
    await _queueStorage.saveQueue(queue);
    _status = _status.copyWith(
      pendingCount: queue.length,
      lastMessage: 'Operacion guardada en el celular para sincronizar luego',
    );
    notifyListeners();
  }

  Future<List<OfflineOperation>> getPendingOperations() => _queueStorage.getQueue();

  Future<void> syncPendingOperations() async {
    if (_status.isSyncing) {
      return;
    }

    final online = await _reachabilityService.canReachBackend();
    if (!online) {
      _status = _status.copyWith(
        isOnline: false,
        lastMessage: 'Sin acceso al backend. Los datos siguen guardados localmente.',
      );
      notifyListeners();
      return;
    }

    final queue = await _queueStorage.getQueue();
    if (queue.isEmpty) {
      _status = _status.copyWith(
        isOnline: true,
        pendingCount: 0,
        lastMessage: 'Todo sincronizado',
      );
      notifyListeners();
      return;
    }

    _status = _status.copyWith(
      isOnline: true,
      isSyncing: true,
      pendingCount: queue.length,
      lastMessage: 'Sincronizando datos pendientes...',
    );
    notifyListeners();

    final remaining = <OfflineOperation>[];
    for (final operation in queue) {
      try {
        await _sendOperation(operation);
      } catch (error) {
        remaining.add(
          operation.copyWith(
            status: 'failed',
            errorMessage: error.toString(),
          ),
        );
      }
    }

    await _queueStorage.saveQueue(remaining);
    _status = _status.copyWith(
      isSyncing: false,
      pendingCount: remaining.length,
      lastMessage: remaining.isEmpty
          ? 'Sincronizacion completada'
          : 'Quedaron ${remaining.length} operaciones pendientes',
    );
    notifyListeners();
  }

  Future<void> _sendOperation(OfflineOperation operation) async {
    switch (operation.method.toUpperCase()) {
      case 'POST':
        await _apiClient.post(operation.path, operation.payload);
        return;
      default:
        throw Exception('Metodo no soportado en sync: ${operation.method}');
    }
  }
}
