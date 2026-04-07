import 'package:flutter/material.dart';

import '../data/mobile_assets_repository.dart';
import '../domain/assets_models.dart';

class AssetsIncomeScreen extends StatefulWidget {
  const AssetsIncomeScreen({super.key});

  @override
  State<AssetsIncomeScreen> createState() => _AssetsIncomeScreenState();
}

class _AssetsIncomeScreenState extends State<AssetsIncomeScreen> {
  final _repository = MobileAssetsRepository();
  final _tabController = ValueNotifier<int>(0);

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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate(
    BuildContext dialogContext,
    TextEditingController controller,
    void Function(void Function())? setDialogState,
  ) async {
    final initialDate = DateTime.tryParse(controller.text) ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: dialogContext,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) {
      return;
    }

    final update = () => controller.text = _formatDate(pickedDate);
    if (setDialogState != null) {
      setDialogState(update);
    } else {
      update();
    }
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                  readOnly: true,
                  onTap: () => _pickDate(context, purchaseDateController, setDialogState),
                  decoration: const InputDecoration(
                    labelText: 'Fecha compra',
                    suffixIcon: Icon(Icons.calendar_month_rounded),
                  ),
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                  readOnly: true,
                  onTap: () => _pickDate(context, incomeDateController, setDialogState),
                  decoration: const InputDecoration(
                    labelText: 'Fecha',
                    suffixIcon: Icon(Icons.calendar_month_rounded),
                  ),
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

    return DefaultTabController(
      length: 2,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TabBar(
                      onTap: (index) => _tabController.value = index,
                      tabs: const [
                        Tab(text: 'Activos', icon: Icon(Icons.home_work_rounded)),
                        Tab(text: 'Ingresos', icon: Icon(Icons.trending_up_rounded)),
                      ],
                    ),
                  ),
                ),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_message!),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        children: [
                          if (_assets.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Todavia no hay activos guardados en el celular.'),
                              ),
                            ),
                          ..._assets.map(
                            (asset) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.home_work_rounded),
                                title: Text(asset.name),
                                subtitle: Text('${asset.owner ?? 'Sin propietario'} · ${asset.purchaseDate ?? 'Sin fecha'}'),
                                trailing: SizedBox(
                                  width: 168,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '\$${asset.value.toStringAsFixed(2)}',
                                          textAlign: TextAlign.end,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Editar',
                                        onPressed: () => _openAssetDialog(asset: asset),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Eliminar',
                                        onPressed: () => _deleteAsset(asset),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        children: [
                          if (_income.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Todavia no hay ingresos guardados en el celular.'),
                              ),
                            ),
                          ..._income.map(
                            (income) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.trending_up_rounded),
                                title: Text(income.source),
                                subtitle: Text('${income.userName ?? 'Sin usuario'} · ${income.incomeDate}'),
                                trailing: SizedBox(
                                  width: 168,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '\$${income.amount.toStringAsFixed(2)}',
                                          textAlign: TextAlign.end,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Editar',
                                        onPressed: () => _openIncomeDialog(income: income),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Eliminar',
                                        onPressed: () => _deleteIncome(income),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 20,
            bottom: 20,
            child: ValueListenableBuilder<int>(
              valueListenable: _tabController,
              builder: (context, activeTab, _) {
                final isAssetsTab = activeTab == 0;
                return FloatingActionButton(
                  onPressed: isAssetsTab ? () => _openAssetDialog() : () => _openIncomeDialog(),
                  tooltip: isAssetsTab ? 'Agregar activo' : 'Agregar ingreso',
                  child: const Icon(Icons.add_rounded),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
