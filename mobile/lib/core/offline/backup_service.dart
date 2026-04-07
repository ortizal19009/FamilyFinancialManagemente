import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/api_config.dart';
import 'local_database.dart';

class BackupService {
  static const _currentFormatVersion = 1;
  static const _requiredTables = {
    'app_cache',
    'offline_queue',
    'local_users',
  };

  BackupService({LocalDatabase? localDatabase})
      : _localDatabase = localDatabase ?? LocalDatabase.instance;

  final LocalDatabase _localDatabase;

  Future<String> exportBackup() async {
    final data = await _localDatabase.exportData();
    final baseUrl = await ApiConfig.getBaseUrl();
    final backupPayload = {
      ...data,
      'app_id': 'family_finance_mobile',
      'format_version': _currentFormatVersion,
      'settings': {
        'base_url': baseUrl,
      },
    };

    final directory = await getTemporaryDirectory();
    final fileName =
        'family_finance_backup_${DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-')}.json';
    final file = File(p.join(directory.path, fileName));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(backupPayload),
    );

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Respaldo de Family Finance Mobile',
    );

    return file.path;
  }

  Future<bool> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    final file = result?.files.single;
    if (file == null || file.path == null) {
      return false;
    }

    final raw = await File(file.path!).readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('El archivo no tiene un formato valido');
    }

    _validateBackup(decoded);
    await _localDatabase.importData(decoded);

    final settings = decoded['settings'];
    if (settings is Map<String, dynamic>) {
      final baseUrl = settings['base_url']?.toString();
      if (baseUrl != null && baseUrl.isNotEmpty) {
        await ApiConfig.saveBaseUrl(baseUrl);
      }
    }

    return true;
  }

  void _validateBackup(Map<String, dynamic> backup) {
    final appId = backup['app_id']?.toString();
    if (appId != 'family_finance_mobile') {
      throw Exception('El archivo no corresponde a Family Finance Mobile');
    }

    final formatVersion = backup['format_version'];
    if (formatVersion is! int) {
      throw Exception('El archivo no tiene version valida');
    }

    if (formatVersion > _currentFormatVersion) {
      throw Exception(
        'El respaldo fue creado con una version mas nueva de la app',
      );
    }

    final tables = backup['tables'];
    if (tables is! Map<String, dynamic>) {
      throw Exception('El archivo no contiene tablas validas');
    }

    final tableNames = tables.keys.toSet();
    final missingTables = _requiredTables.difference(tableNames);
    if (missingTables.isNotEmpty) {
      throw Exception(
        'El respaldo esta incompleto. Faltan tablas requeridas: ${missingTables.join(', ')}',
      );
    }
  }
}
