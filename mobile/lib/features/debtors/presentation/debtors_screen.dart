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
  List<SmallDebtSummary> _smallDebts = [];
  bool _loading = true;
  bool _loadedFromCache = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final (debtors, smallDebts, loadedFromCache) = await _repository.loadDebtors();
    if (!mounted) return;
    setState(() {
      _debtors = debtors;
      _smallDebts = smallDebts;
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

  Future<void> _openSmallDebtDialog({SmallDebtSummary? debt}) async {
    final lenderController = TextEditingController(text: debt?.lenderName ?? '');
    final amountController = TextEditingController(
      text: debt == null ? '0' : debt.amount.toStringAsFixed(2),
    );
    final descriptionController = TextEditingController(text: debt?.description ?? '');
    final borrowedDateController = TextEditingController(text: debt?.borrowedDate ?? '');
    final dueDateController = TextEditingController(text: debt?.dueDate ?? '');
    String selectedStatus = debt?.status ?? 'pendiente';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(debt == null ? 'Nueva deuda pequena' : 'Editar deuda pequena'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: lenderController, decoration: const InputDecoration(labelText: 'A quien le debo')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Monto'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: borrowedDateController,
                    decoration: const InputDecoration(labelText: 'Fecha prestamo (YYYY-MM-DD)'),
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
      if (debt == null) {
        await _repository.createSmallDebt(
          lenderName: lenderController.text.trim(),
          amount: double.tryParse(amountController.text.trim()) ?? 0,
          description: descriptionController.text.trim(),
          borrowedDate: borrowedDateController.text.trim().isEmpty ? null : borrowedDateController.text.trim(),
          dueDate: dueDateController.text.trim().isEmpty ? null : dueDateController.text.trim(),
          status: selectedStatus,
        );
        _message = 'Deuda guardada correctamente';
      } else {
        await _repository.updateSmallDebt(
          id: debt.id,
          lenderName: lenderController.text.trim(),
          amount: double.tryParse(amountController.text.trim()) ?? 0,
          description: descriptionController.text.trim(),
          borrowedDate: borrowedDateController.text.trim().isEmpty ? null : borrowedDateController.text.trim(),
          dueDate: dueDateController.text.trim().isEmpty ? null : dueDateController.text.trim(),
          status: selectedStatus,
        );
        _message = 'Deuda actualizada correctamente';
      }
      await _loadData();
    } catch (error) {
      setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteSmallDebt(SmallDebtSummary debt) async {
    try {
      await _repository.deleteSmallDebt(debt.id);
      _message = 'Deuda eliminada correctamente';
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
      child: RefreshIndicator(
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
                        Text('Deudores y deudas pequenas', style: Theme.of(context).textTheme.titleLarge),
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
            const TabBar(
              tabs: [
                Tab(text: 'Deudores'),
                Tab(text: 'Deudas pequenas'),
              ],
            ),
            SizedBox(
              height: 640,
              child: TabBarView(
                children: [
                  ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () => _openDebtorDialog(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Agregar'),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                            trailing: SizedBox(
                              width: 168,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '\$${debtor.amountOwed.toStringAsFixed(2)}',
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _openDebtorDialog(debtor: debtor),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteDebtor(debtor),
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
                  ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () => _openSmallDebtDialog(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Agregar'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_smallDebts.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Todavia no hay deudas pequenas sincronizadas.'),
                          ),
                        ),
                      ..._smallDebts.map(
                        (debt) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.person_outline_rounded),
                            title: Text(debt.lenderName),
                            subtitle: Text('${debt.status} · ${debt.dueDate ?? 'Sin fecha de vencimiento'}'),
                            trailing: SizedBox(
                              width: 168,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '\$${debt.amount.toStringAsFixed(2)}',
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _openSmallDebtDialog(debt: debt),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteSmallDebt(debt),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
