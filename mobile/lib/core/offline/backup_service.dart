import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/api_config.dart';
import 'local_database.dart';

class BackupService {
  BackupService({LocalDatabase? localDatabase})
      : _localDatabase = localDatabase ?? LocalDatabase.instance;

  final LocalDatabase _localDatabase;

  Future<String> exportBackup() async {
    final data = await _localDatabase.exportData();
    final baseUrl = await ApiConfig.getBaseUrl();
    final backupPayload = {
      ...data,
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

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Respaldo de Family Finance Mobile',
      ),
    );

    return file.path;
  }

  Future<void> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    final file = result?.files.single;
    if (file == null || file.path == null) {
      throw Exception('No seleccionaste ningun archivo');
    }

    final raw = await File(file.path!).readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('El archivo no tiene un formato valido');
    }

    await _localDatabase.importData(decoded);

    final settings = decoded['settings'];
    if (settings is Map<String, dynamic>) {
      final baseUrl = settings['base_url']?.toString();
      if (baseUrl != null && baseUrl.isNotEmpty) {
        await ApiConfig.saveBaseUrl(baseUrl);
      }
    }
  }
}
