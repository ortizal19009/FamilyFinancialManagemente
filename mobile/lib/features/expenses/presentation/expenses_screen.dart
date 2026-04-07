import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../banks/domain/bank_models.dart';
import '../../cards/domain/cards_models.dart';
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
  final _dateController = TextEditingController();

  List<ExpenseCategory> _categories = [];
  List<MobileExpenseRecord> _expenses = [];
  List<CardSummary> _cards = [];
  List<BankAccountSummary> _accounts = [];
  List<_ExpenseDraftItem> _items = [];
  String _paymentMethod = 'Efectivo';
  int? _selectedCardId;
  int? _selectedAccountId;
  bool _loading = true;
  bool _saving = false;
  String? _message;
  String? _receiptPath;
  String? _receiptName;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _dateController.text = _formatDate(today);
    _loadData();
    AppServices.syncService.addListener(_handleSyncChange);
  }

  @override
  void dispose() {
    AppServices.syncService.removeListener(_handleSyncChange);
    _descriptionController.dispose();
    _dateController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadData() async {
    final categories = await _repository.loadCategories();
    final expenses = await _repository.loadExpenses();
    List<CardSummary> cards = _cards;
    List<BankAccountSummary> accounts = _accounts;

    try {
      cards = await _repository.loadCards();
      accounts = await _repository.loadAccounts();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _categories = categories;
      _expenses = expenses;
      _cards = cards;
      _accounts = accounts;
      if (_items.isEmpty && categories.isNotEmpty) {
        _items = [_ExpenseDraftItem(categoryId: categories.first.id)];
      }
      _loading = false;
    });
  }

  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );

    final file = result?.files.single;
    if (file == null || file.path == null) {
      return;
    }

    setState(() {
      _receiptPath = file.path;
      _receiptName = file.name;
    });
  }

  bool get _usesCard =>
      _paymentMethod == 'Tarjeta Crédito' || _paymentMethod == 'Tarjeta Débito';

  bool get _usesAccount => _paymentMethod == 'Banca Móvil';

  void _handlePaymentMethodChange(String value) {
    setState(() {
      _paymentMethod = value;
      if (!_usesCard) {
        _selectedCardId = null;
      }
      if (!_usesAccount) {
        _selectedAccountId = null;
      }
    });
  }

  void _addItem() {
    final defaultCategoryId = _categories.isNotEmpty ? _categories.first.id : null;
    setState(() {
      _items.add(_ExpenseDraftItem(categoryId: defaultCategoryId));
    });
  }

  void _removeItem(int index) {
    if (_items.length == 1) {
      return;
    }

    setState(() {
      final item = _items.removeAt(index);
      item.dispose();
    });
  }

  double get _totalAmount {
    return _items.fold<double>(
      0,
      (sum, item) => sum + (double.tryParse(item.amountController.text.trim()) ?? 0),
    );
  }

  List<Map<String, dynamic>> _buildItems() {
    return _items
        .where((item) => item.categoryId != null)
        .map(
          (item) => {
            'category_id': item.categoryId,
            'amount': double.tryParse(item.amountController.text.trim()) ?? 0,
          },
        )
        .toList();
  }

  Future<void> _saveExpense() async {
    final description = _descriptionController.text.trim();
    final expenseDate = _dateController.text.trim();
    final items = _buildItems();

    if (description.isEmpty || expenseDate.isEmpty || items.isEmpty) {
      setState(() => _message = 'Completa descripcion, fecha y al menos un rubro');
      return;
    }

    if (items.any((item) => (item['amount'] as double) <= 0)) {
      setState(() => _message = 'Cada rubro debe tener un monto mayor a 0');
      return;
    }

    if (_usesCard && _selectedCardId == null) {
      setState(() => _message = 'Selecciona la tarjeta usada en el gasto');
      return;
    }

    if (_usesAccount && _selectedAccountId == null) {
      setState(() => _message = 'Selecciona la cuenta usada en el gasto');
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      final hadReceipt = _receiptPath != null;
      await _repository.addExpenseOffline(
        description: description,
        items: items,
        paymentMethod: _paymentMethod,
        expenseDate: expenseDate,
        cardId: _selectedCardId,
        bankAccountId: _selectedAccountId,
        receiptPath: _receiptPath,
      );

      if (_receiptPath == null && AppServices.syncService.status.isOnline) {
        await AppServices.syncService.syncPendingOperations();
      }

      await _loadData();
      _resetForm();
      _message = hadReceipt
          ? 'Gasto y factura enviados correctamente'
          : 'Gasto guardado correctamente';
    } catch (error) {
      _message = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _resetForm() {
    _descriptionController.clear();
    _dateController.text = _formatDate(DateTime.now());
    for (final item in _items) {
      item.dispose();
    }
    _items = [
      _ExpenseDraftItem(
        categoryId: _categories.isNotEmpty ? _categories.first.id : null,
      ),
    ];
    _paymentMethod = 'Efectivo';
    _selectedCardId = null;
    _selectedAccountId = null;
    _receiptPath = null;
    _receiptName = null;
  }

  Future<void> _editExpense(MobileExpenseRecord expense) async {
    if (expense.serverId == null) {
      setState(() => _message = 'Solo puedes editar gastos ya sincronizados');
      return;
    }

    final descriptionController = TextEditingController(text: expense.description);
    final dateController = TextEditingController(text: expense.expenseDate);
    String paymentMethod = expense.paymentMethod;
    int? selectedCardId = expense.cardId;
    int? selectedAccountId = expense.bankAccountId;
    final editItems = (expense.items.isNotEmpty
            ? expense.items
            : [
                {
                  'category_id': expense.categoryId,
                  'amount': expense.amount,
                }
              ])
        .map(
          (item) => _ExpenseDraftItem(
            categoryId: item['category_id'] as int?,
            amount: (item['amount'] as num?)?.toDouble(),
          ),
        )
        .toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Editar gasto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Descripcion'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dateController,
                      decoration: const InputDecoration(labelText: 'Fecha (YYYY-MM-DD)'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: paymentMethod,
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
                        setDialogState(() => paymentMethod = value);
                      },
                    ),
                    if (paymentMethod == 'Tarjeta Crédito' || paymentMethod == 'Tarjeta Débito') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: selectedCardId,
                        decoration: const InputDecoration(labelText: 'Tarjeta'),
                        items: _cards
                            .map(
                              (card) => DropdownMenuItem(
                                value: card.id,
                                child: Text('${card.cardName} · ${card.bankName}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setDialogState(() => selectedCardId = value),
                      ),
                    ],
                    if (paymentMethod == 'Banca Móvil') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: selectedAccountId,
                        decoration: const InputDecoration(labelText: 'Cuenta'),
                        items: _accounts
                            .map(
                              (account) => DropdownMenuItem(
                                value: account.id,
                                child: Text('${account.bankName} · ${account.accountNumber}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setDialogState(() => selectedAccountId = value),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ...editItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int>(
                                initialValue: item.categoryId,
                                decoration: InputDecoration(labelText: 'Rubro ${index + 1}'),
                                items: _categories
                                    .map(
                                      (category) => DropdownMenuItem(
                                        value: category.id,
                                        child: Text(category.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) => item.categoryId = value,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: item.amountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Monto'),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      for (final item in editItems) {
        item.dispose();
      }
      return;
    }

    final updatedItems = editItems
        .where((item) => item.categoryId != null)
        .map(
          (item) => {
            'category_id': item.categoryId,
            'amount': double.tryParse(item.amountController.text.trim()) ?? 0,
          },
        )
        .toList();

    setState(() => _saving = true);
    try {
      await _repository.updateExpense(
        expenseId: expense.serverId!,
        description: descriptionController.text.trim(),
        paymentMethod: paymentMethod,
        expenseDate: dateController.text.trim(),
        items: updatedItems,
        cardId: paymentMethod == 'Tarjeta Crédito' || paymentMethod == 'Tarjeta Débito'
            ? selectedCardId
            : null,
        bankAccountId: paymentMethod == 'Banca Móvil' ? selectedAccountId : null,
      );
      _message = 'Gasto actualizado correctamente';
      await _loadData();
    } catch (error) {
      _message = error.toString().replaceFirst('Exception: ', '');
    } finally {
      for (final item in editItems) {
        item.dispose();
      }
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteExpense(MobileExpenseRecord expense) async {
    if (expense.serverId == null) {
      setState(() => _message = 'Solo puedes eliminar gastos ya sincronizados');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: Text('Se eliminara el gasto "${expense.description}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _saving = true);
    try {
      await _repository.deleteExpense(expense.serverId!);
      _message = 'Gasto eliminado correctamente';
      await _loadData();
    } catch (error) {
      _message = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
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
                      Text('Registrar gasto', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        syncStatus.isOnline
                            ? 'Puedes registrar un gasto con varios rubros y controlar la tarjeta o cuenta utilizada.'
                            : 'Sin backend disponible. Los gastos sin archivo se guardaran para sincronizar luego.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Descripcion'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _dateController,
                        decoration: const InputDecoration(labelText: 'Fecha (YYYY-MM-DD)'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _paymentMethod,
                        decoration: const InputDecoration(labelText: 'Metodo de pago'),
                        items: const [
                          'Efectivo',
                          'Tarjeta Crédito',
                          'Tarjeta Débito',
                          'Banca Móvil',
                          'Fiado',
                        ].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          _handlePaymentMethodChange(value);
                        },
                      ),
                      if (_usesCard) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _selectedCardId,
                          decoration: const InputDecoration(labelText: 'Tarjeta utilizada'),
                          items: _cards
                              .map(
                                (card) => DropdownMenuItem(
                                  value: card.id,
                                  child: Text(
                                    '${card.cardName} · ${card.cardType} · saldo ${card.cardType == 'Crédito' ? (card.creditLimit - card.currentDebt).toStringAsFixed(2) : card.availableBalance.toStringAsFixed(2)}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() => _selectedCardId = value),
                        ),
                      ],
                      if (_usesAccount) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _selectedAccountId,
                          decoration: const InputDecoration(labelText: 'Cuenta utilizada'),
                          items: _accounts
                              .map(
                                (account) => DropdownMenuItem(
                                  value: account.id,
                                  child: Text(
                                    '${account.bankName} · ${account.accountNumber} · saldo ${account.currentBalance.toStringAsFixed(2)}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() => _selectedAccountId = value),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: Text('Rubros', style: Theme.of(context).textTheme.titleMedium)),
                          TextButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            label: const Text('Agregar rubro'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<int>(
                                  initialValue: item.categoryId,
                                  decoration: InputDecoration(labelText: 'Rubro ${index + 1}'),
                                  items: _categories
                                      .map((category) => DropdownMenuItem(value: category.id, child: Text(category.name)))
                                      .toList(),
                                  onChanged: (value) => setState(() => item.categoryId = value),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: item.amountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Monto'),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _items.length == 1 ? null : () => _removeItem(index),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Text('Total: \$${_totalAmount.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _pickReceipt,
                        icon: const Icon(Icons.attach_file_rounded),
                        label: Text(_receiptName ?? 'Adjuntar factura (foto o PDF)'),
                      ),
                      if (_receiptName != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: Text(_receiptName!)),
                            TextButton(
                              onPressed: () => setState(() {
                                _receiptPath = null;
                                _receiptName = null;
                              }),
                              child: const Text('Quitar'),
                            ),
                          ],
                        ),
                      ],
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
                              child: Text(_saving ? 'Guardando...' : 'Guardar gasto'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: syncStatus.isSyncing ? null : () => AppServices.syncService.syncPendingOperations(),
                            child: Text(syncStatus.isSyncing ? 'Sincronizando...' : 'Sincronizar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Gastos recientes', style: Theme.of(context).textTheme.titleLarge),
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
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editExpense(expense);
                        } else if (value == 'delete') {
                          _deleteExpense(expense);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                      ],
                      child: Column(
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
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExpenseDraftItem {
  _ExpenseDraftItem({this.categoryId, double? amount})
      : amountController = TextEditingController(
          text: amount == null ? '' : amount.toStringAsFixed(2),
        );

  int? categoryId;
  final TextEditingController amountController;

  void dispose() {
    amountController.dispose();
  }
}
