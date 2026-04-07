import 'dart:convert';

import 'offline_operation.dart';
import 'local_database.dart';

class OfflineQueueStorage {
  Future<List<OfflineOperation>> getQueue() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'offline_queue',
      orderBy: 'created_at ASC',
    );
    return rows
        .map(
          (row) => OfflineOperation.fromMap({
            'id': row['id'],
            'module': row['module'],
            'method': row['method'],
            'path': row['path'],
            'payload': row['payload'],
            'created_at': row['created_at'],
            'status': row['status'],
            'error_message': row['error_message'],
          }),
        )
        .toList();
  }

  Future<void> saveQueue(List<OfflineOperation> queue) async {
    final db = await LocalDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('offline_queue');
      for (final item in queue) {
        await txn.insert('offline_queue', {
          'id': item.id,
          'module': item.module,
          'method': item.method,
          'path': item.path,
          'payload': jsonEncode(item.payload),
          'created_at': item.createdAt.toIso8601String(),
          'status': item.status,
          'error_message': item.errorMessage,
        });
      }
    });
  }
}
