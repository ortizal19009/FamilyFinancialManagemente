import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../data/mobile_debtors_repository.dart';
import '../domain/debtor_models.dart';

class DebtorsScreen extends StatefulWidget {
  const DebtorsScreen({super.key});

  @override
  State<DebtorsScreen> createState() => _DebtorsScreenState();
}

class _DebtorsScreenState extends State<DebtorsScreen> {
  final _repository = MobileDebtorsRepository();

  List<DebtorSummary> _debtors = [];
  bool _loading = true;
  bool _loadedFromCache = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final (debtors, loadedFromCache) = await _repository.loadDebtors();
    if (!mounted) return;
    setState(() {
      _debtors = debtors;
      _loadedFromCache = loadedFromCache;
      _loading = false;
    });
  }

  Future<void> _openDebtorDialog({DebtorSummary? debtor}) async {
    final nameController = TextEditingController(text: debtor?.name ?? '');
    final amountController = TextEditingController(
      text: debtor == null ? '0' : debtor.amountOwed.toStringAsFixed(2),
    );
    final descriptionController = TextEditingController(text: debtor?.description ?? '');
    final dueDateController = TextEditingController(text: debtor?.dueDate ?? '');
    String selectedStatus = debtor?.status ?? 'pendiente';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(debtor == null ? 'Nuevo deudor' : 'Editar deudor'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Monto adeudado'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dueDateController,
                    decoration: const InputDecoration(labelText: 'Vence (YYYY-MM-DD)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: const [
                      DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                      DropdownMenuItem(value: 'pagado', child: Text('Pagado')),
                      DropdownMenuItem(value: 'vencido', child: Text('Vencido')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedStatus = value);
                    },
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
      },
    );

    if (confirmed != true) return;

    try {
      if (debtor == null) {
        await _repository.createDebtor(
          name: nameController.text.trim(),
          amountOwed: double.tryParse(amountController.text.trim()) ?? 0,
          description: descriptionController.text.trim(),
          dueDate: dueDateController.text.trim().isEmpty ? null : dueDateController.text.trim(),
          status: selectedStatus,
        );
        _message = 'Deudor guardado correctamente';
      } else {
        await _repository.updateDebtor(
          id: debtor.id,
          name: nameController.text.trim(),
          amountOwed: double.tryParse(amountController.text.trim()) ?? 0,
          description: descriptionController.text.trim(),
          dueDate: dueDateController.text.trim().isEmpty ? null : dueDateController.text.trim(),
          status: selectedStatus,
        );
        _message = 'Deudor actualizado correctamente';
      }
      await _loadData();
    } catch (error) {
      setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteDebtor(DebtorSummary debtor) async {
    try {
      await _repository.deleteDebtor(debtor.id);
      _message = 'Deudor eliminado correctamente';
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
                      Row(
                        children: [
                          Expanded(child: Text('Deudores', style: Theme.of(context).textTheme.titleLarge)),
                          FilledButton.icon(
                            onPressed: () => _openDebtorDialog(),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Agregar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_loadedFromCache ? 'Mostrando la ultima informacion guardada localmente.' : 'Datos cargados desde el backend.'),
                      const SizedBox(height: 8),
                      Text(syncStatus.isOnline ? 'Backend disponible.' : 'Sin acceso al backend.'),
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
          if (_debtors.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Todavia no hay deudores sincronizados.'),
              ),
            ),
          ..._debtors.map(
            (debtor) => Card(
              child: ListTile(
                leading: const Icon(Icons.group_rounded),
                title: Text(debtor.name),
                subtitle: Text('${debtor.status} · ${debtor.dueDate ?? 'Sin fecha de vencimiento'}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openDebtorDialog(debtor: debtor);
                    } else if (value == 'delete') {
                      _deleteDebtor(debtor);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                  child: Text('\$${debtor.amountOwed.toStringAsFixed(2)}'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
