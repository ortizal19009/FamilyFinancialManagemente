import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/auth/data/local_auth_storage.dart';
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
    LocalAuthStorage? localAuthStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _queueStorage = queueStorage ?? OfflineQueueStorage(),
        _reachabilityService = reachabilityService ?? BackendReachabilityService(),
        _localAuthStorage = localAuthStorage ?? LocalAuthStorage();

  final ApiClient _apiClient;
  final OfflineQueueStorage _queueStorage;
  final BackendReachabilityService _reachabilityService;
  final LocalAuthStorage _localAuthStorage;
  StreamSubscription<Object?>? _connectivitySubscription;
  bool _initialized = false;

  SyncStatus _status = SyncStatus.initial();
  SyncStatus get status => _status;

  Future<void> initialize() async {
    if (_initialized) {
      await refreshState();
      return;
    }
    _initialized = true;

    await refreshState();

    _connectivitySubscription = _reachabilityService.connectivityStream.listen((_) async {
      final canReach = await _reachabilityService.canReachBackend();
      if (_status.isOnline == canReach) {
        return;
      }

      _status = _status.copyWith(isOnline: canReach);
      notifyListeners();
    });
  }

  Future<void> refreshState() async {
    final queue = await _queueStorage.getQueue();
    final online = await _reachabilityService.canReachBackend();
    _status = _status.copyWith(
      isOnline: online,
      pendingCount: queue.length,
    );
    notifyListeners();
  }

  Future<void> enqueue(OfflineOperation operation) async {
    final queue = await _queueStorage.getQueue();
    queue.add(operation);
    await _queueStorage.saveQueue(queue);
    _status = _status.copyWith(
      pendingCount: queue.length,
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
      );
      notifyListeners();
      return;
    }

    final queue = await _queueStorage.getQueue();
    if (queue.isEmpty) {
      _status = _status.copyWith(
        isOnline: true,
        pendingCount: 0,
      );
      notifyListeners();
      return;
    }

    _status = _status.copyWith(
      isOnline: true,
      isSyncing: true,
      pendingCount: queue.length,
    );
    notifyListeners();

    final remaining = <OfflineOperation>[];
    for (final operation in queue) {
      try {
        await _sendOperation(operation);
      } catch (error) {
        if (await _shouldTreatAsSynced(operation, error)) {
          continue;
        }
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
    );
    notifyListeners();
  }

  Future<void> _sendOperation(OfflineOperation operation) async {
    switch (operation.method.toUpperCase()) {
      case 'POST':
        await _apiClient.post(
          operation.path,
          operation.payload,
          auth: operation.path != '/auth/register',
        );
        if (operation.path == '/auth/register') {
          final email = operation.payload['email']?.toString();
          if (email != null && email.isNotEmpty) {
            await _localAuthStorage.markServerSynced(email);
          }
        }
        return;
      default:
        throw Exception('Metodo no soportado en sync: ${operation.method}');
    }
  }

  Future<bool> _shouldTreatAsSynced(OfflineOperation operation, Object error) async {
    if (operation.path != '/auth/register') {
      return false;
    }

    final message = error.toString().toLowerCase();
    if (!message.contains('user already exists')) {
      return false;
    }

    final email = operation.payload['email']?.toString();
    if (email == null || email.isEmpty) {
      return false;
    }

    await _localAuthStorage.markServerSynced(email);
    return true;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
