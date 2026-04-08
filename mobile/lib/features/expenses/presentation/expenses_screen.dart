import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/app_services.dart';
import '../../banks/domain/bank_models.dart';
import '../../cards/domain/cards_models.dart';
import '../data/mobile_expenses_repository.dart';
import '../domain/expense_category.dart';
import '../domain/expense_icon_option.dart';
import '../domain/mobile_expense_record.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    super.key,
    this.autoStartVoice = false,
  });

  final bool autoStartVoice;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _repository = MobileExpensesRepository();
  final _searchController = TextEditingController();
  final SpeechToText _speechToText = SpeechToText();

  List<ExpenseCategory> _categories = [];
  List<MobileExpenseRecord> _expenses = [];
  List<CardSummary> _cards = [];
  List<BankAccountSummary> _accounts = [];
  bool _loading = true;
  bool _saving = false;
  bool _speechAvailable = false;
  bool _listeningToVoice = false;
  bool _autoStartedVoice = false;
  String? _message;
  String _paymentMethodFilter = 'Todos';
  String _sortOption = 'date_desc';

  @override
  void initState() {
    super.initState();
    _loadData();
    _initializeSpeech();
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

  Future<void> _initializeSpeech() async {
    try {
      final available = await _speechToText.initialize(
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _listeningToVoice = false;
            _message =
                'El microfono no esta disponible. En emulador verifica permiso de microfono, imagen con Google y reconocimiento de voz habilitado.';
          });
        },
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listeningToVoice = false);
          }
        },
      );
      if (!mounted) return;
      setState(() => _speechAvailable = available);
      if (available && widget.autoStartVoice && !_autoStartedVoice) {
        _autoStartedVoice = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _toggleVoiceExpense();
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _speechAvailable = false);
    }
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
    String selectedIcon = expenseIconOptions.first.key;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuevo rubro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre del rubro'),
                ),
                const SizedBox(height: 16),
                Text('Galeria de iconos', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: expenseIconOptions.map((option) {
                    final selected = option.key == selectedIcon;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedIcon = option.key),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 92,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(option.icon),
                            const SizedBox(height: 6),
                            Text(
                              option.label,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
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
        icon: selectedIcon,
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

  Future<void> _openCreateExpenseDialog({
    String? initialDescription,
    List<Map<String, dynamic>>? initialItems,
  }) async {
    final descriptionController = TextEditingController(text: initialDescription ?? '');
    final dateController = TextEditingController(text: _formatDate(DateTime.now()));
    String paymentMethod = 'Efectivo';
    int? selectedCardId;
    int? selectedAccountId;
    String? receiptPath;
    String? receiptName;
    final seedItems = initialItems ?? const [];
    final draftItems = seedItems.isNotEmpty
        ? seedItems
            .map(
              (item) => _ExpenseDraftItem(
                categoryId: item['category_id'] as int?,
                amount: (item['amount'] as num?)?.toDouble(),
              ),
            )
            .toList()
        : [
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

  Future<void> _toggleVoiceExpense() async {
    if (_listeningToVoice) {
      await _stopVoiceRecognition();
      return;
    }

    if (!_speechAvailable) {
      await _initializeSpeech();
    }

    if (!_speechAvailable) {
      setState(() {
        _message =
            'El reconocimiento de voz no esta disponible en este dispositivo. En emulador prueba habilitar microfono, instalar servicios de Google y volver a abrir la app.';
      });
      return;
    }

    String capturedWords = '';
    setState(() {
      _listeningToVoice = true;
      _message = 'Escuchando gasto por voz...';
    });

    await _speechToText.listen(
      localeId: 'es',
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
      onResult: (result) {
        capturedWords = result.recognizedWords.trim();
      },
    );

    await Future<void>.delayed(const Duration(seconds: 12));
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
    if (!mounted) return;

    setState(() => _listeningToVoice = false);
    final transcript = capturedWords.trim();
    if (transcript.isEmpty) {
      setState(() => _message = 'No pude entender el audio. Intenta de nuevo.');
      return;
    }

    final parsedItems = _suggestItemsFromTranscript(transcript);
    setState(() => _message = 'Audio reconocido: $transcript');
    await _openCreateExpenseDialog(
      initialDescription: transcript,
      initialItems: parsedItems,
    );
  }

  Future<void> _stopVoiceRecognition() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
    if (!mounted) return;
    setState(() => _listeningToVoice = false);
  }

  List<Map<String, dynamic>> _suggestItemsFromTranscript(String transcript) {
    final guessedCategoryId = _guessCategoryId(transcript);
    final guessedAmount = _extractAmountFromTranscript(transcript);
    return [
      {
        'category_id': guessedCategoryId ?? (_categories.isNotEmpty ? _categories.first.id : null),
        'amount': guessedAmount > 0 ? guessedAmount : 0.0,
      },
    ];
  }

  int? _guessCategoryId(String transcript) {
    final normalized = _normalizeTranscript(transcript);
    final keywordMap = <String, List<String>>{
      'alimentos': ['supermercado', 'comida', 'almuerzo', 'desayuno', 'cena', 'mercado'],
      'medicina': ['farmacia', 'medicina', 'medicamento', 'doctor'],
      'vivienda': ['alquiler', 'casa', 'arriendo'],
      'transporte': ['taxi', 'uber', 'gasolina', 'pasaje', 'bus'],
      'educacion': ['colegio', 'escuela', 'universidad', 'cuaderno', 'matricula'],
      'entretenimiento': ['cine', 'salida', 'juego', 'fiesta'],
      'servicios basicos': ['luz', 'agua', 'internet', 'telefono'],
    };

    for (final category in _categories) {
      final categoryName = _normalizeTranscript(category.name);
      if (normalized.contains(categoryName)) {
        return category.id;
      }
      for (final keyword in keywordMap[categoryName] ?? const <String>[]) {
        if (normalized.contains(keyword)) {
          return category.id;
        }
      }
    }
    return null;
  }

  double _extractAmountFromTranscript(String transcript) {
    final amountRegex = RegExp(r'(\d+[.,]?\d{0,2})');
    final matches = amountRegex.allMatches(transcript);
    if (matches.isEmpty) {
      return 0;
    }
    final rawValue = matches.last.group(1)?.replaceAll(',', '.') ?? '0';
    return double.tryParse(rawValue) ?? 0;
  }

  String _normalizeTranscript(String value) {
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ñ': 'n',
    };

    var normalized = value.toLowerCase();
    replacements.forEach((key, replacement) {
      normalized = normalized.replaceAll(key, replacement);
    });
    return normalized;
  }

  Future<void> _showAudioHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ayuda para ingreso por audio'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Habla en una sola frase y menciona, si puedes, estos datos:',
              ),
              SizedBox(height: 12),
              Text('1. Que compraste o para que fue el gasto.'),
              Text('2. El monto.'),
              Text('3. La forma de pago.'),
              Text('4. La tarjeta, banco o cuenta usada si aplica.'),
              SizedBox(height: 16),
              Text('Ejemplos recomendados:'),
              SizedBox(height: 8),
              Text('Compre supermercado por 25 dolares en efectivo'),
              Text('Pague farmacia 18.50 con tarjeta de credito Visa'),
              Text('Gaste 12 en taxi con banca movil desde Banco Pichincha'),
              Text('Pague internet 30 dolares con tarjeta de debito'),
              SizedBox(height: 16),
              Text('Consejos:'),
              SizedBox(height: 8),
              Text('Menciona solo un gasto por audio.'),
              Text('Di el monto al final o muy cerca del producto.'),
              Text('Usa palabras claras como efectivo, tarjeta de credito, tarjeta de debito o banca movil.'),
              Text('Si el sistema no detecta todo, igual abrira el formulario para que completes o corrijas.'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
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
          bottom: 164,
          child: FloatingActionButton.small(
            heroTag: 'voice-help-fab',
            onPressed: _showAudioHelp,
            tooltip: 'Ayuda audio',
            child: const Icon(Icons.help_outline_rounded),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 92,
          child: FloatingActionButton.small(
            heroTag: 'voice-expense-fab',
            onPressed: _saving ? null : _toggleVoiceExpense,
            tooltip: _listeningToVoice ? 'Detener audio' : 'Registrar por audio',
            child: Icon(_listeningToVoice ? Icons.mic_off_rounded : Icons.mic_rounded),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            heroTag: 'create-expense-fab',
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
