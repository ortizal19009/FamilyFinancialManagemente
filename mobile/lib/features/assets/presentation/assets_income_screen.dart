import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../data/mobile_assets_repository.dart';
import '../domain/assets_models.dart';

class AssetsIncomeScreen extends StatefulWidget {
  const AssetsIncomeScreen({super.key});

  @override
  State<AssetsIncomeScreen> createState() => _AssetsIncomeScreenState();
}

class _AssetsIncomeScreenState extends State<AssetsIncomeScreen> {
  final _repository = MobileAssetsRepository();

  List<AssetSummary> _assets = [];
  List<IncomeSummary> _income = [];
  bool _loading = true;
  bool _loadedFromCache = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final snapshot = await _repository.loadSnapshot();
    if (!mounted) return;
    setState(() {
      _assets = snapshot.assets;
      _income = snapshot.income;
      _loadedFromCache = snapshot.loadedFromCache;
      _loading = false;
    });
  }

  Future<void> _openAssetDialog({AssetSummary? asset}) async {
    final nameController = TextEditingController(text: asset?.name ?? '');
    final ownerController = TextEditingController(text: asset?.owner ?? '');
    final descriptionController = TextEditingController(text: asset?.description ?? '');
    final valueController = TextEditingController(
      text: asset == null ? '0' : asset.value.toStringAsFixed(2),
    );
    final purchaseDateController = TextEditingController(text: asset?.purchaseDate ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(asset == null ? 'Nuevo activo/inversion' : 'Editar activo/inversion'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 12),
              TextField(controller: ownerController, decoration: const InputDecoration(labelText: 'Propietario')),
              const SizedBox(height: 12),
              TextField(
                controller: valueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: purchaseDateController,
                decoration: const InputDecoration(labelText: 'Fecha compra (YYYY-MM-DD)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Descripcion'),
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Guardar')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (asset == null) {
        await _repository.createAsset(
          name: nameController.text.trim(),
          value: double.tryParse(valueController.text.trim()) ?? 0,
          owner: ownerController.text.trim(),
          description: descriptionController.text.trim(),
          purchaseDate: purchaseDateController.text.trim().isEmpty ? null : purchaseDateController.text.trim(),
        );
        _message = 'Activo guardado correctamente';
      } else {
        await _repository.updateAsset(
          id: asset.id,
          name: nameController.text.trim(),
          value: double.tryParse(valueController.text.trim()) ?? 0,
          owner: ownerController.text.trim(),
          description: descriptionController.text.trim(),
          purchaseDate: purchaseDateController.text.trim().isEmpty ? null : purchaseDateController.text.trim(),
        );
        _message = 'Activo actualizado correctamente';
      }
      await _loadData();
    } catch (error) {
      setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openIncomeDialog({IncomeSummary? income}) async {
    final sourceController = TextEditingController(text: income?.source ?? '');
    final descriptionController = TextEditingController(text: income?.description ?? '');
    final amountController = TextEditingController(
      text: income == null ? '0' : income.amount.toStringAsFixed(2),
    );
    final incomeDateController = TextEditingController(text: income?.incomeDate ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(income == null ? 'Nuevo ingreso' : 'Editar ingreso'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: sourceController, decoration: const InputDecoration(labelText: 'Fuente')),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: incomeDateController,
                decoration: const InputDecoration(labelText: 'Fecha (YYYY-MM-DD)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Descripcion'),
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Guardar')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (income == null) {
        await _repository.createIncome(
          amount: double.tryParse(amountController.text.trim()) ?? 0,
          source: sourceController.text.trim(),
          incomeDate: incomeDateController.text.trim(),
          description: descriptionController.text.trim(),
        );
        _message = 'Ingreso guardado correctamente';
      } else {
        await _repository.updateIncome(
          id: income.id,
          amount: double.tryParse(amountController.text.trim()) ?? 0,
          source: sourceController.text.trim(),
          incomeDate: incomeDateController.text.trim(),
          description: descriptionController.text.trim(),
        );
        _message = 'Ingreso actualizado correctamente';
      }
      await _loadData();
    } catch (error) {
      setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteAsset(AssetSummary asset) async {
    try {
      await _repository.deleteAsset(asset.id);
      _message = 'Activo eliminado correctamente';
      await _loadData();
    } catch (error) {
      setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteIncome(IncomeSummary income) async {
    try {
      await _repository.deleteIncome(income.id);
      _message = 'Ingreso eliminado correctamente';
      await _loadData();
    } catch (error) {
      setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          AnimatedBuilder(
            animation: AppServices.syncService,
            builder: (context, _) {
              final syncStatus = AppServices.syncService.status;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Activos, ingresos e inversiones', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(_loadedFromCache ? 'Mostrando la ultima informacion guardada localmente.' : 'Datos cargados desde el backend.'),
                      const SizedBox(height: 8),
                      Text(syncStatus.isOnline ? 'Backend disponible.' : 'Sin acceso al backend.'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () => _openAssetDialog(),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Activo'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _openIncomeDialog(),
                            icon: const Icon(Icons.trending_up_rounded),
                            label: const Text('Ingreso'),
                          ),
                        ],
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Text(_message!),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Activos / Inversiones', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_assets.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Todavia no hay activos sincronizados.'),
              ),
            ),
          ..._assets.map(
            (asset) => Card(
              child: ListTile(
                leading: const Icon(Icons.home_work_rounded),
                title: Text(asset.name),
                subtitle: Text('${asset.owner ?? 'Sin propietario'} · ${asset.purchaseDate ?? 'Sin fecha'}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openAssetDialog(asset: asset);
                    } else if (value == 'delete') {
                      _deleteAsset(asset);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                  child: Text('\$${asset.value.toStringAsFixed(2)}'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Ingresos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_income.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Todavia no hay ingresos sincronizados.'),
              ),
            ),
          ..._income.map(
            (income) => Card(
              child: ListTile(
                leading: const Icon(Icons.trending_up_rounded),
                title: Text(income.source),
                subtitle: Text('${income.userName ?? 'Sin usuario'} · ${income.incomeDate}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openIncomeDialog(income: income);
                    } else if (value == 'delete') {
                      _deleteIncome(income);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                  child: Text('\$${income.amount.toStringAsFixed(2)}'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
