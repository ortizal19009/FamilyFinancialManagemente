import 'package:flutter/material.dart';

import '../../../app.dart';
import '../../../core/config/api_config.dart';
import '../../../core/app_services.dart';
import '../../../core/offline/backup_service.dart';
import '../../../core/offline/backend_reachability_service.dart';
import '../../../core/theme/theme_controller.dart';

class BackendSettingsScreen extends StatefulWidget {
  const BackendSettingsScreen({super.key});

  @override
  State<BackendSettingsScreen> createState() => _BackendSettingsScreenState();
}

class _BackendSettingsScreenState extends State<BackendSettingsScreen> {
  final _controller = TextEditingController();
  final _reachabilityService = BackendReachabilityService();
  final _backupService = BackupService();
  bool _loading = true;
  bool _checkingConnection = false;
  bool _uploadingServerInfo = false;
  bool _downloadingServerInfo = false;
  bool _exporting = false;
  bool _importing = false;
  String? _message;

  ThemeOption? _selectedThemeOption;

  @override
  void initState() {
    super.initState();
    _loadCurrentValue();
  }

  Future<void> _loadCurrentValue() async {
    final value = await ApiConfig.getBaseUrl();
    if (!mounted) return;
    final themeController = FamilyFinanceApp.of(context)?.themeController;
    setState(() {
      _controller.text = value;
      _selectedThemeOption = themeController == null
          ? null
          : ThemeController.options.firstWhere(
              (option) => option.id == themeController.selectedThemeId,
              orElse: () => ThemeController.options.first,
            );
      _loading = false;
    });
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _message = 'Ingresa la direccion del backend');
      return;
    }

    await ApiConfig.saveBaseUrl(value);
    if (!mounted) return;
    setState(() => _message = 'Configuracion guardada correctamente');
  }

  Future<void> _reset() async {
    await ApiConfig.resetBaseUrl();
    await _loadCurrentValue();
    if (!mounted) return;
    setState(() => _message = 'Se restauro la configuracion por defecto');
  }

  Future<void> _checkConnection() async {
    setState(() {
      _checkingConnection = true;
      _message = 'Comprobando conectividad con el servidor...';
    });

    final hasConnection = await _reachabilityService.canReachBackend();
    if (!mounted) return;

    setState(() {
      _checkingConnection = false;
      _message = hasConnection
          ? 'Conexion exitosa con el servidor'
          : 'No se pudo conectar con el servidor';
    });
  }

  Future<void> _exportBackup() async {
    setState(() {
      _exporting = true;
      _message = 'Generando respaldo...';
    });

    try {
      final path = await _backupService.exportBackup();
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Respaldo exportado. Archivo generado: $path';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _importBackup() async {
    setState(() {
      _importing = true;
      _message = 'Importando respaldo...';
    });

    try {
      final imported = await _backupService.importBackup();
      if (!imported) {
        if (!mounted) {
          return;
        }
        setState(() {
          _message = 'Importacion cancelada';
        });
        return;
      }
      await AppServices.syncService.refreshState();
      await _loadCurrentValue();
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Respaldo importado correctamente';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _uploadInfo() async {
    setState(() {
      _uploadingServerInfo = true;
      _message = 'Enviando cambios pendientes al servidor...';
    });

    try {
      await AppServices.syncService.syncPendingOperations();
      await AppServices.syncService.refreshState();
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Upload completado. Los cambios pendientes se enviaron al servidor.';
      });
      AppServices.requestDataRefresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _uploadingServerInfo = false);
      }
    }
  }

  Future<void> _downloadInfo() async {
    setState(() {
      _downloadingServerInfo = true;
      _message = 'Descargando informacion mas reciente del servidor...';
    });

    try {
      await AppServices.syncService.refreshState();
      if (!mounted) {
        return;
      }
      AppServices.requestDataRefresh();
      setState(() {
        _message = 'Download completado. La app recargara los datos desde el servidor.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _downloadingServerInfo = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = FamilyFinanceApp.of(context);
    final themeController = appState?.themeController;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracion'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Temas',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Selecciona una paleta predefinida para personalizar la apariencia de la app movil.',
                          ),
                          const SizedBox(height: 16),
                          if (themeController != null)
                            DropdownButtonFormField<String>(
                              initialValue: (_selectedThemeOption ?? ThemeController.options.first).id,
                              decoration: const InputDecoration(
                                labelText: 'Tema predefinido',
                              ),
                              items: ThemeController.options
                                  .map(
                                    (option) => DropdownMenuItem<String>(
                                      value: option.id,
                                      child: Text(option.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) async {
                                if (value == null) return;
                                final selected = ThemeController.options.firstWhere(
                                  (option) => option.id == value,
                                );
                                await themeController.selectTheme(value);
                                if (!mounted) return;
                                setState(() {
                                  _selectedThemeOption = selected;
                                  _message = 'Tema aplicado: ${selected.label}';
                                });
                              },
                            ),
                          if (_selectedThemeOption != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: _selectedThemeOption!.previewColors
                                  .map(
                                    (color) => Container(
                                      width: 22,
                                      height: 22,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Configuracion',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'La app movil se conecta al backend HTTP, no directamente a la base de datos. Aqui puedes cambiar host, IP, puerto y base path del backend.',
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              labelText: 'URL base del backend',
                              hintText: 'http://192.168.1.10:5000/api',
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Ejemplos validos: `http://10.0.2.2:5000/api`, `http://192.168.1.50:8000/api` o `mi-servidor.local:5000`.',
                          ),
                          if (_message != null) ...[
                            const SizedBox(height: 12),
                            Text(_message!),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: _save,
                                  child: const Text('Guardar'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _reset,
                                  child: const Text('Restaurar'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _checkingConnection ? null : _checkConnection,
                              icon: _checkingConnection
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.wifi_tethering_rounded),
                              label: Text(
                                _checkingConnection
                                    ? 'Comprobando...'
                                    : 'Comprobar conectividad con el servidor',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _uploadingServerInfo || _downloadingServerInfo
                                      ? null
                                      : _uploadInfo,
                                  icon: _uploadingServerInfo
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.cloud_upload_rounded),
                                  label: Text(
                                    _uploadingServerInfo ? 'Uploading...' : 'Upload info',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _uploadingServerInfo || _downloadingServerInfo
                                      ? null
                                      : _downloadInfo,
                                  icon: _downloadingServerInfo
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.cloud_download_rounded),
                                  label: Text(
                                    _downloadingServerInfo ? 'Downloading...' : 'Download info',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Respaldo local',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Exporta tu data local a un archivo JSON para guardarla como backup o restaurarla en otro celular.',
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _exporting || _importing ? null : _exportBackup,
                                  icon: _exporting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.upload_file_rounded),
                                  label: Text(_exporting ? 'Exportando...' : 'Exportar data'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _exporting || _importing ? null : _importBackup,
                                  icon: _importing
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.download_rounded),
                                  label: Text(_importing ? 'Importando...' : 'Importar data'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Si una version nueva agrega campos, al importar se conservara lo existente y los campos faltantes quedaran vacios hasta que los completes manualmente.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
