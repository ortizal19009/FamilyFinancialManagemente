import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();
  Database? _database;
  static const _excludedTables = {'android_metadata', 'sqlite_sequence'};

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, 'family_finance_mobile.db');
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE app_cache (
            cache_key TEXT PRIMARY KEY,
            cache_value TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE offline_queue (
            id TEXT PRIMARY KEY,
            module TEXT NOT NULL,
            method TEXT NOT NULL,
            path TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            status TEXT NOT NULL,
            error_message TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE local_users (
            email TEXT PRIMARY KEY,
            full_name TEXT NOT NULL,
            password TEXT NOT NULL,
            role TEXT NOT NULL,
            created_at TEXT NOT NULL,
            server_synced INTEGER NOT NULL DEFAULT 0,
            last_synced_at TEXT
          )
        ''');
      },
    );
    return _database!;
  }

  Future<Map<String, dynamic>> exportData() async {
    final db = await database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
    );

    final payload = <String, dynamic>{};
    for (final row in tables) {
      final tableName = row['name'] as String? ?? '';
      if (_excludedTables.contains(tableName)) {
        continue;
      }

      payload[tableName] = await db.query(tableName);
    }

    return {
      'format_version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': payload,
    };
  }

  Future<void> importData(Map<String, dynamic> backup) async {
    final db = await database;
    final rawTables = backup['tables'];
    if (rawTables is! Map) {
      throw Exception('El archivo no contiene tablas validas');
    }

    final tableMap = Map<String, dynamic>.from(rawTables);
    final currentTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
    );
    final availableTables = currentTables
        .map((row) => row['name'] as String? ?? '')
        .where((name) => name.isNotEmpty && !_excludedTables.contains(name))
        .toList();

    await db.transaction((txn) async {
      for (final table in availableTables) {
        await txn.delete(table);
      }

      for (final entry in tableMap.entries) {
        final tableName = entry.key;
        if (!availableTables.contains(tableName)) {
          continue;
        }

        final rows = entry.value;
        if (rows is! List) {
          continue;
        }

        final columnsInfo = await txn.rawQuery('PRAGMA table_info($tableName)');
        final validColumns = columnsInfo
            .map((column) => column['name'] as String? ?? '')
            .where((name) => name.isNotEmpty)
            .toSet();

        for (final row in rows) {
          if (row is! Map) {
            continue;
          }

          final normalizedRow = <String, Object?>{};
          for (final key in row.keys) {
            final columnName = key.toString();
            if (!validColumns.contains(columnName)) {
              continue;
            }
            normalizedRow[columnName] = row[key];
          }

          if (normalizedRow.isEmpty) {
            continue;
          }

          await txn.insert(
            tableName,
            normalizedRow,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }
}
