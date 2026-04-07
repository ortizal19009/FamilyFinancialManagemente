import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'local_database.dart';

class LocalCacheStorage {
  Future<void> saveCollection(String key, List<Map<String, dynamic>> items) async {
    final db = await LocalDatabase.instance.database;
    await db.insert(
      'app_cache',
      {
        'cache_key': key,
        'cache_value': jsonEncode(items),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCollection(String key) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'app_cache',
      columns: ['cache_value'],
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final raw = rows.first['cache_value'] as String?;
    if (raw == null || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final data = jsonDecode(raw) as List<dynamic>;
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}
