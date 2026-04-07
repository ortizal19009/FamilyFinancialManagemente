import 'package:flutter/material.dart';

import '../data/mobile_debtors_repository.dart';
import '../domain/debtor_models.dart';

class DebtorsScreen extends StatefulWidget {
  const DebtorsScreen({super.key});

  @override
  State<DebtorsScreen> createState() => _DebtorsScreenState();
}

class _DebtorsScreenState extends State<DebtorsScreen> {
  final _repository = MobileDebtorsRepository();
  final _tabController = ValueNotifier<int>(0);

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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate(
    BuildContext dialogContext,
    TextEditingController controller,
    void Function(void Function()) setDialogState,
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

    setDialogState(() {
      controller.text = _formatDate(pickedDate);
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
                    readOnly: true,
                    onTap: () => _pickDate(context, dueDateController, setDialogState),
                    decoration: const InputDecoration(
                      labelText: 'Vence',
                      suffixIcon: Icon(Icons.calendar_month_rounded),
                    ),
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
                    readOnly: true,
                    onTap: () => _pickDate(context, borrowedDateController, setDialogState),
                    decoration: const InputDecoration(
                      labelText: 'Fecha prestamo',
                      suffixIcon: Icon(Icons.calendar_month_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dueDateController,
                    readOnly: true,
                    onTap: () => _pickDate(context, dueDateController, setDialogState),
                    decoration: const InputDecoration(
                      labelText: 'Vence',
                      suffixIcon: Icon(Icons.calendar_month_rounded),
                    ),
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
                        Tab(text: 'Deudores'),
                        Tab(text: 'Deudas pequenas'),
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
                          if (_debtors.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Todavia no hay deudores guardados en el celular.'),
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
                    ),
                    RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        children: [
                          if (_smallDebts.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Todavia no hay deudas pequenas guardadas en el celular.'),
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
                final isDebtorsTab = activeTab == 0;
                return FloatingActionButton(
                  onPressed: isDebtorsTab ? () => _openDebtorDialog() : () => _openSmallDebtDialog(),
                  tooltip: isDebtorsTab ? 'Agregar deudor' : 'Agregar deuda pequena',
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
