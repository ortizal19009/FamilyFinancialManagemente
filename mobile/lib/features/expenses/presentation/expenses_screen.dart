import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../data/mobile_expenses_repository.dart';
import '../domain/expense_category.dart';
import '../domain/mobile_expense_record.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _repository = MobileExpensesRepository();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  List<ExpenseCategory> _categories = [];
  List<MobileExpenseRecord> _expenses = [];
  ExpenseCategory? _selectedCategory;
  String _paymentMethod = 'Efectivo';
  bool _loading = true;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadData();
    AppServices.syncService.addListener(_handleSyncChange);
  }

  @override
  void dispose() {
    AppServices.syncService.removeListener(_handleSyncChange);
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final categories = await _repository.loadCategories();
    final expenses = await _repository.loadExpenses();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _selectedCategory = categories.isNotEmpty ? categories.first : null;
      _expenses = expenses;
      _loading = false;
    });
  }

  Future<void> _saveExpense() async {
    final category = _selectedCategory;
    final amount = double.tryParse(_amountController.text.trim());
    if (category == null || amount == null || amount <= 0 || _descriptionController.text.trim().isEmpty) {
      setState(() {
        _message = 'Completa descripcion, categoria y monto valido';
      });
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });

    final today = DateTime.now();
    final expenseDate =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    await _repository.addExpenseOffline(
      description: _descriptionController.text.trim(),
      amount: amount,
      category: category,
      paymentMethod: _paymentMethod,
      expenseDate: expenseDate,
    );

    await _loadData();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _descriptionController.clear();
      _amountController.clear();
      _message = 'Gasto guardado en el celular. Se sincronizara cuando haya conexion con el backend.';
    });
  }

  Future<void> _handleSyncChange() async {
    if (!mounted) return;
    if (!AppServices.syncService.status.isSyncing) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return AnimatedBuilder(
      animation: AppServices.syncService,
      builder: (context, _) {
        final syncStatus = AppServices.syncService.status;

        return RefreshIndicator(
          onRefresh: () async {
            await AppServices.syncService.syncPendingOperations();
            await _loadData();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registrar gasto offline',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        syncStatus.isOnline
                            ? 'Tienes acceso al backend. Puedes guardar y sincronizar.'
                            : 'Estas fuera de red o sin acceso al backend. Los gastos se guardaran localmente.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Descripcion'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Monto'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ExpenseCategory>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(labelText: 'Categoria'),
                        items: _categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedCategory = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        decoration: const InputDecoration(labelText: 'Metodo de pago'),
                        items: const [
                          'Efectivo',
                          'Tarjeta Crédito',
                          'Tarjeta Débito',
                          'Banca Móvil',
                          'Fiado',
                        ]
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _paymentMethod = value);
                        },
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
                              onPressed: _saving ? null : _saveExpense,
                              child: Text(_saving ? 'Guardando...' : 'Guardar en el celular'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: syncStatus.isSyncing
                                ? null
                                : () => AppServices.syncService.syncPendingOperations(),
                            child: Text(syncStatus.isSyncing ? 'Sincronizando...' : 'Sincronizar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Gastos recientes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (_expenses.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Todavia no hay gastos en cache local.'),
                  ),
                ),
              ..._expenses.map(
                (expense) => Card(
                  child: ListTile(
                    title: Text(expense.description),
                    subtitle: Text('${expense.categoryName} · ${expense.paymentMethod} · ${expense.expenseDate}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('\$${expense.amount.toStringAsFixed(2)}'),
                        const SizedBox(height: 4),
                        Text(
                          expense.syncStatus == 'synced' ? 'Sincronizado' : 'Pendiente',
                          style: TextStyle(
                            fontSize: 12,
                            color: expense.syncStatus == 'synced' ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
