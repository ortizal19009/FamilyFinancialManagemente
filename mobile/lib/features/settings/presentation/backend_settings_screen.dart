import 'package:flutter/material.dart';

import '../../../core/config/api_config.dart';

class BackendSettingsScreen extends StatefulWidget {
  const BackendSettingsScreen({super.key});

  @override
  State<BackendSettingsScreen> createState() => _BackendSettingsScreenState();
}

class _BackendSettingsScreenState extends State<BackendSettingsScreen> {
  final _controller = TextEditingController();
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadCurrentValue();
  }

  Future<void> _loadCurrentValue() async {
    final value = await ApiConfig.getBaseUrl();
    if (!mounted) return;
    setState(() {
      _controller.text = value;
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracion backend'),
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
                            'Conexion del backend',
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
