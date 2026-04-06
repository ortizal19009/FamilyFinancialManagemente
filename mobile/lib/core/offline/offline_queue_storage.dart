import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'offline_operation.dart';

class OfflineQueueStorage {
  static const _queueKey = 'offline_queue';

  Future<List<OfflineOperation>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_queueKey) ?? <String>[];
    return rawItems.map(OfflineOperation.fromJson).toList();
  }

  Future<void> saveQueue(List<OfflineOperation> queue) async {
    final prefs = await SharedPreferences.getInstance();
    final items = queue.map((item) => jsonEncode(item.toMap())).toList();
    await prefs.setStringList(_queueKey, items);
  }
}
