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
  final _searchController = TextEditingController();

  List<ExpenseCategory> _categories = [];
  List<MobileExpenseRecord> _expenses = [];
  List<CardSummary> _cards = [];
  List<BankAccountSummary> _accounts = [];
  bool _loading = true;
  bool _saving = false;
  String? _message;
  String _paymentMethodFilter = 'Todos';
  String _sortOption = 'date_desc';

  @override
  void initState() {
    super.initState();
    _loadData();
    AppServices.syncService.addListener(_handleSyncChange);
  }

  @override
  void dispose() {
    AppServices.syncService.removeListener(_handleSyncChange);
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initialDate = DateTime.tryParse(controller.text) ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      controller.text = _formatDate(pickedDate);
    });
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
      _loading = false;
    });
  }

  Future<PlatformFile?> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );

    final file = result?.files.single;
    if (file == null || file.path == null) {
      return null;
    }
    return file;
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
                      readOnly: true,
                      onTap: () => _pickDate(dateController),
                      decoration: const InputDecoration(
                        labelText: 'Fecha',
                        suffixIcon: Icon(Icons.calendar_month_rounded),
                      ),
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

  Future<ExpenseCategory?> _openCreateCategoryDialog() async {
    final nameController = TextEditingController();
    final iconController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo rubro'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre del rubro'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: iconController,
                decoration: const InputDecoration(labelText: 'Icono opcional'),
              ),
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
      ),
    );

    if (confirmed != true) {
      return null;
    }

    final name = nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _message = 'El nombre del rubro es obligatorio');
      return null;
    }

    setState(() => _saving = true);
    try {
      final category = await _repository.createCategory(
        name: name,
        icon: iconController.text.trim().isEmpty ? null : iconController.text.trim(),
      );
      await _loadData();
      _message = 'Rubro creado correctamente';
      return category;
    } catch (error) {
      setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
      return null;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openCreateExpenseDialog() async {
    final descriptionController = TextEditingController();
    final dateController = TextEditingController(text: _formatDate(DateTime.now()));
    String paymentMethod = 'Efectivo';
    int? selectedCardId;
    int? selectedAccountId;
    String? receiptPath;
    String? receiptName;
    final draftItems = [
      _ExpenseDraftItem(categoryId: _categories.isNotEmpty ? _categories.first.id : null),
    ];

    double totalAmount() => draftItems.fold<double>(
          0,
          (sum, item) => sum + (double.tryParse(item.amountController.text.trim()) ?? 0),
        );

    bool usesCard() => paymentMethod == 'Tarjeta Crédito' || paymentMethod == 'Tarjeta Débito';
    bool usesAccount() => paymentMethod == 'Banca Móvil';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nuevo gasto'),
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
                      readOnly: true,
                      onTap: () => _pickDate(dateController),
                      decoration: const InputDecoration(
                        labelText: 'Fecha',
                        suffixIcon: Icon(Icons.calendar_month_rounded),
                      ),
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
                      ].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          paymentMethod = value;
                          if (!usesCard()) {
                            selectedCardId = null;
                          }
                          if (!usesAccount()) {
                            selectedAccountId = null;
                          }
                        });
                      },
                    ),
                    if (usesCard()) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: selectedCardId,
                        decoration: const InputDecoration(labelText: 'Tarjeta utilizada'),
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
                    if (usesAccount()) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: selectedAccountId,
                        decoration: const InputDecoration(labelText: 'Cuenta utilizada'),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Rubros', style: Theme.of(context).textTheme.titleMedium),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            final defaultCategoryId = _categories.isNotEmpty ? _categories.first.id : null;
                            setDialogState(() {
                              draftItems.add(_ExpenseDraftItem(categoryId: defaultCategoryId));
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: const Text('Agregar'),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final newCategory = await _openCreateCategoryDialog();
                          if (newCategory == null) return;
                          setDialogState(() {
                            if (draftItems.isNotEmpty && draftItems.first.categoryId == null) {
                              draftItems.first.categoryId = newCategory.id;
                            }
                          });
                        },
                        icon: const Icon(Icons.playlist_add_rounded),
                        label: const Text('Crear rubro'),
                      ),
                    ),
                    if (_categories.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Todavia no tienes rubros. Crea uno para comenzar.'),
                        ),
                      ),
                    ...draftItems.asMap().entries.map((entry) {
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
                                onChanged: (value) => setDialogState(() => item.categoryId = value),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: item.amountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Monto'),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: draftItems.length == 1
                                  ? null
                                  : () => setDialogState(() {
                                        final removed = draftItems.removeAt(index);
                                        removed.dispose();
                                      }),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Total: \$${totalAmount().toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final file = await _pickReceipt();
                        if (file == null) return;
                        setDialogState(() {
                          receiptPath = file.path;
                          receiptName = file.name;
                        });
                      },
                      icon: const Icon(Icons.attach_file_rounded),
                      label: Text(receiptName ?? 'Adjuntar factura (foto o PDF)'),
                    ),
                    if (receiptName != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: Text(receiptName!)),
                          TextButton(
                            onPressed: () => setDialogState(() {
                              receiptPath = null;
                              receiptName = null;
                            }),
                            child: const Text('Quitar'),
                          ),
                        ],
                      ),
                    ],
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
      for (final item in draftItems) {
        item.dispose();
      }
      return;
    }

    final description = descriptionController.text.trim();
    final expenseDate = dateController.text.trim();
    final items = draftItems
        .where((item) => item.categoryId != null)
        .map(
          (item) => {
            'category_id': item.categoryId,
            'amount': double.tryParse(item.amountController.text.trim()) ?? 0,
          },
        )
        .toList();

    if (description.isEmpty || expenseDate.isEmpty || items.isEmpty) {
      setState(() => _message = 'Completa descripcion, fecha y al menos un rubro');
      for (final item in draftItems) {
        item.dispose();
      }
      return;
    }

    if (items.any((item) => (item['amount'] as double) <= 0)) {
      setState(() => _message = 'Cada rubro debe tener un monto mayor a 0');
      for (final item in draftItems) {
        item.dispose();
      }
      return;
    }

    if (usesCard() && selectedCardId == null) {
      setState(() => _message = 'Selecciona la tarjeta usada en el gasto');
      for (final item in draftItems) {
        item.dispose();
      }
      return;
    }

    if (usesAccount() && selectedAccountId == null) {
      setState(() => _message = 'Selecciona la cuenta usada en el gasto');
      for (final item in draftItems) {
        item.dispose();
      }
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await _repository.addExpenseOffline(
        description: description,
        items: items,
        paymentMethod: paymentMethod,
        expenseDate: expenseDate,
        cardId: selectedCardId,
        bankAccountId: selectedAccountId,
        receiptPath: receiptPath,
      );
      if (receiptPath == null && AppServices.syncService.status.isOnline) {
        await AppServices.syncService.syncPendingOperations();
      }
      await _loadData();
      _message = 'Gasto guardado correctamente';
    } catch (error) {
      _message = error.toString().replaceFirst('Exception: ', '');
    } finally {
      for (final item in draftItems) {
        item.dispose();
      }
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  List<MobileExpenseRecord> get _filteredExpenses {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _expenses.where((expense) {
      final matchesMethod = _paymentMethodFilter == 'Todos' || expense.paymentMethod == _paymentMethodFilter;
      final searchable = [
        expense.description,
        expense.categoryName,
        expense.paymentMethod,
        expense.expenseDate,
        expense.amount.toStringAsFixed(2),
      ].join(' ').toLowerCase();
      final matchesQuery = query.isEmpty || searchable.contains(query);
      return matchesMethod && matchesQuery;
    }).toList();

    filtered.sort((a, b) {
      switch (_sortOption) {
        case 'date_asc':
          return a.expenseDate.compareTo(b.expenseDate);
        case 'amount_desc':
          return b.amount.compareTo(a.amount);
        case 'amount_asc':
          return a.amount.compareTo(b.amount);
        case 'type_asc':
          return a.paymentMethod.compareTo(b.paymentMethod);
        case 'date_desc':
        default:
          return b.expenseDate.compareTo(a.expenseDate);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final visibleExpenses = _filteredExpenses;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            await AppServices.syncService.syncPendingOperations();
            await _loadData();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Buscar por fecha, tipo, rubro, descripcion o monto',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _paymentMethodFilter,
                        decoration: const InputDecoration(labelText: 'Filtrar por tipo'),
                        items: const [
                          'Todos',
                          'Efectivo',
                          'Tarjeta Crédito',
                          'Tarjeta Débito',
                          'Banca Móvil',
                          'Fiado',
                        ].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _paymentMethodFilter = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _sortOption,
                        decoration: const InputDecoration(labelText: 'Ordenar por'),
                        items: const [
                          DropdownMenuItem(value: 'date_desc', child: Text('Fecha mas reciente')),
                          DropdownMenuItem(value: 'date_asc', child: Text('Fecha mas antigua')),
                          DropdownMenuItem(value: 'amount_desc', child: Text('Monto mayor')),
                          DropdownMenuItem(value: 'amount_asc', child: Text('Monto menor')),
                          DropdownMenuItem(value: 'type_asc', child: Text('Tipo de pago')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _sortOption = value);
                        },
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Text(_message!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: visibleExpenses.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No hay gastos que coincidan con tu filtro.'),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Fecha')),
                              DataColumn(label: Text('Descripcion')),
                              DataColumn(label: Text('Rubro')),
                              DataColumn(label: Text('Tipo')),
                              DataColumn(label: Text('Monto')),
                              DataColumn(label: Text('Estado')),
                              DataColumn(label: Text('Acciones')),
                            ],
                            rows: visibleExpenses
                                .map(
                                  (expense) => DataRow(
                                    cells: [
                                      DataCell(Text(expense.expenseDate)),
                                      DataCell(
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 180),
                                          child: Text(expense.description, overflow: TextOverflow.ellipsis),
                                        ),
                                      ),
                                      DataCell(Text(expense.categoryName)),
                                      DataCell(Text(expense.paymentMethod)),
                                      DataCell(Text('\$${expense.amount.toStringAsFixed(2)}')),
                                      DataCell(
                                        Text(
                                          expense.syncStatus == 'synced' ? 'Sincronizado' : 'Pendiente',
                                          style: TextStyle(
                                            color: expense.syncStatus == 'synced' ? Colors.green : Colors.orange,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        PopupMenuButton<String>(
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
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            onPressed: _saving ? null : _openCreateExpenseDialog,
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
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
