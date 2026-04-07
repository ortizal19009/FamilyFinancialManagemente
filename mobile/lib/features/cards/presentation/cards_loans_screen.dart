import 'package:flutter/material.dart';

import '../../banks/domain/bank_models.dart';
import '../data/mobile_cards_repository.dart';
import '../domain/cards_models.dart';

class CardsLoansScreen extends StatefulWidget {
  const CardsLoansScreen({super.key});

  @override
  State<CardsLoansScreen> createState() => _CardsLoansScreenState();
}

class _CardsLoansScreenState extends State<CardsLoansScreen> {
  final _repository = MobileCardsRepository();
  final _tabController = ValueNotifier<int>(0);

  List<CardSummary> _cards = [];
  List<LoanSummary> _loans = [];
  List<BankSummary> _banks = [];
  bool _loading = true;
  bool _loadedFromCache = false;
  bool _saving = false;
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
    List<BankSummary> banks = _banks;
    try {
      banks = await _repository.loadBanks();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _cards = snapshot.cards;
      _loans = snapshot.loans;
      _banks = banks;
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

  Future<void> _openCardDialog({CardSummary? card}) async {
    final bankOptions = _banks;
    if (bankOptions.isEmpty) {
      setState(() => _message = 'Primero debes registrar al menos un banco');
      return;
    }

    final cardNameController = TextEditingController(text: card?.cardName ?? '');
    final ownerController = TextEditingController(text: card?.owner ?? '');
    final lastDigitsController = TextEditingController(text: card?.lastFourDigits ?? '');
    final limitController = TextEditingController(
      text: card == null ? '0' : card.creditLimit.toStringAsFixed(2),
    );
    final debtController = TextEditingController(
      text: card == null ? '0' : card.currentDebt.toStringAsFixed(2),
    );
    final availableController = TextEditingController(
      text: card == null ? '0' : card.availableBalance.toStringAsFixed(2),
    );

    int selectedBankId = card?.bankId ?? bankOptions.first.id;
    String selectedType = card?.cardType ?? 'Débito';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(card == null ? 'Nueva tarjeta' : 'Editar tarjeta'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedBankId,
                      decoration: const InputDecoration(labelText: 'Banco'),
                      items: bankOptions
                          .map(
                            (bank) => DropdownMenuItem(
                              value: bank.id,
                              child: Text(bank.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedBankId = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cardNameController,
                      decoration: const InputDecoration(labelText: 'Nombre de la tarjeta'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ownerController,
                      decoration: const InputDecoration(labelText: 'Titular'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lastDigitsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Ultimos 4 digitos'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: const [
                        DropdownMenuItem(value: 'Débito', child: Text('Débito')),
                        DropdownMenuItem(value: 'Crédito', child: Text('Crédito')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: limitController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Limite de credito'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: debtController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Deuda actual'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: availableController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Saldo disponible'),
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
                  child: Text(card == null ? 'Agregar' : 'Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) {
      return;
    }

    final cardName = cardNameController.text.trim();
    if (cardName.isEmpty) {
      setState(() => _message = 'El nombre de la tarjeta es obligatorio');
      return;
    }

    setState(() => _saving = true);
    try {
      if (card == null) {
        await _repository.createCard(
          bankId: selectedBankId,
          cardName: cardName,
          owner: ownerController.text.trim(),
          lastFourDigits: lastDigitsController.text.trim(),
          cardType: selectedType,
          creditLimit: double.tryParse(limitController.text.trim()) ?? 0,
          currentDebt: double.tryParse(debtController.text.trim()) ?? 0,
          availableBalance: double.tryParse(availableController.text.trim()) ?? 0,
        );
        _message = 'Tarjeta agregada correctamente';
      } else {
        await _repository.updateCard(
          cardId: card.id,
          bankId: selectedBankId,
          cardName: cardName,
          owner: ownerController.text.trim(),
          lastFourDigits: lastDigitsController.text.trim(),
          cardType: selectedType,
          creditLimit: double.tryParse(limitController.text.trim()) ?? 0,
          currentDebt: double.tryParse(debtController.text.trim()) ?? 0,
          availableBalance: double.tryParse(availableController.text.trim()) ?? 0,
        );
        _message = 'Tarjeta actualizada correctamente';
      }
      await _loadData();
    } catch (error) {
      _message = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteCard(CardSummary card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarjeta'),
        content: Text('Se eliminara "${card.cardName}" si no tiene gastos asociados.'),
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
      await _repository.deleteCard(card.id);
      _message = 'Tarjeta eliminada correctamente';
      await _loadData();
    } catch (error) {
      _message = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openLoanDialog({LoanSummary? loan}) async {
    final descriptionController = TextEditingController(text: loan?.description ?? '');
    final ownerController = TextEditingController(text: loan?.owner ?? '');
    final initialAmountController = TextEditingController(
      text: loan == null ? '0' : loan.initialAmount.toStringAsFixed(2),
    );
    final totalInstallmentsController = TextEditingController(
      text: loan == null ? '1' : loan.totalInstallments.toString(),
    );
    final pendingInstallmentsController = TextEditingController(
      text: loan == null ? '1' : loan.pendingInstallments.toString(),
    );
    final monthlyPaymentController = TextEditingController(
      text: loan == null ? '0' : loan.monthlyPayment.toStringAsFixed(2),
    );
    final interestRateController = TextEditingController(text: '0');
    final startDateController = TextEditingController(text: loan?.startDate ?? '');

    int? selectedBankId = loan?.bankId;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(loan == null ? 'Nuevo prestamo' : 'Editar prestamo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int?>(
                      initialValue: selectedBankId,
                      decoration: const InputDecoration(labelText: 'Banco'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Sin banco')),
                        ..._banks.map(
                          (bank) => DropdownMenuItem<int?>(
                            value: bank.id,
                            child: Text(bank.name),
                          ),
                        ),
                      ],
                      onChanged: (value) => setDialogState(() => selectedBankId = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Descripcion'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ownerController,
                      decoration: const InputDecoration(labelText: 'Titular'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: initialAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Monto inicial'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: monthlyPaymentController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Mensualidad'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: totalInstallmentsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cuotas totales'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pendingInstallmentsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cuotas pendientes'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: interestRateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Interes'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: startDateController,
                      readOnly: true,
                      onTap: () => _pickDate(context, startDateController, setDialogState),
                      decoration: const InputDecoration(
                        labelText: 'Fecha inicio',
                        suffixIcon: Icon(Icons.calendar_month_rounded),
                      ),
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
                  child: Text(loan == null ? 'Agregar' : 'Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) {
      return;
    }

    final description = descriptionController.text.trim();
    if (description.isEmpty) {
      setState(() => _message = 'La descripcion del prestamo es obligatoria');
      return;
    }

    setState(() => _saving = true);
    try {
      if (loan == null) {
        await _repository.createLoan(
          bankId: selectedBankId,
          description: description,
          owner: ownerController.text.trim(),
          initialAmount: double.tryParse(initialAmountController.text.trim()) ?? 0,
          totalInstallments: int.tryParse(totalInstallmentsController.text.trim()) ?? 1,
          pendingInstallments: int.tryParse(pendingInstallmentsController.text.trim()) ?? 1,
          monthlyPayment: double.tryParse(monthlyPaymentController.text.trim()) ?? 0,
          interestRate: double.tryParse(interestRateController.text.trim()),
          startDate: startDateController.text.trim().isEmpty ? null : startDateController.text.trim(),
        );
        _message = 'Prestamo agregado correctamente';
      } else {
        await _repository.updateLoan(
          loanId: loan.id,
          bankId: selectedBankId,
          description: description,
          owner: ownerController.text.trim(),
          initialAmount: double.tryParse(initialAmountController.text.trim()) ?? 0,
          totalInstallments: int.tryParse(totalInstallmentsController.text.trim()) ?? 1,
          pendingInstallments: int.tryParse(pendingInstallmentsController.text.trim()) ?? 1,
          monthlyPayment: double.tryParse(monthlyPaymentController.text.trim()) ?? 0,
          interestRate: double.tryParse(interestRateController.text.trim()),
          startDate: startDateController.text.trim().isEmpty ? null : startDateController.text.trim(),
        );
        _message = 'Prestamo actualizado correctamente';
      }
      await _loadData();
    } catch (error) {
      _message = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteLoan(LoanSummary loan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar prestamo'),
        content: Text('Se eliminara "${loan.description}".'),
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
      await _repository.deleteLoan(loan.id);
      _message = 'Prestamo eliminado correctamente';
      await _loadData();
    } catch (error) {
      _message = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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
                      indicatorSize: TabBarIndicatorSize.tab,
                      onTap: (index) => _tabController.value = index,
                      tabs: const [
                        Tab(text: 'Tarjetas', icon: Icon(Icons.credit_card_rounded)),
                        Tab(text: 'Prestamos', icon: Icon(Icons.request_quote_rounded)),
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
                          if (_cards.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Todavia no hay tarjetas guardadas en el celular.'),
                              ),
                            ),
                          ..._cards.map(
                            (card) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.credit_card_rounded),
                                title: Text('${card.cardName} · ${card.bankName}'),
                                subtitle: Text(
                                  '${card.cardType ?? 'Tarjeta'} · ${card.owner ?? 'Sin propietario'} · **** ${card.lastFourDigits ?? '----'}',
                                ),
                                trailing: SizedBox(
                                  width: 96,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Editar',
                                        onPressed: () => _openCardDialog(card: card),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Eliminar',
                                        onPressed: () => _deleteCard(card),
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
                      if (_loans.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Todavia no hay prestamos guardados en el celular.'),
                          ),
                        ),
                      ..._loans.map(
                        (loan) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.request_quote_rounded),
                            title: Text(loan.description),
                            subtitle: Text(
                              '${loan.bankName} · ${loan.totalInstallments - loan.pendingInstallments}/${loan.totalInstallments} cuotas pagadas',
                            ),
                            trailing: SizedBox(
                              width: 164,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('\$${loan.initialAmount.toStringAsFixed(2)}'),
                                        Text(
                                          'Mensual \$${loan.monthlyPayment.toStringAsFixed(2)}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Editar',
                                    onPressed: () => _openLoanDialog(loan: loan),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Eliminar',
                                    onPressed: () => _deleteLoan(loan),
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
                final isCardsTab = activeTab == 0;
                return FloatingActionButton(
                  onPressed: _saving
                      ? null
                      : isCardsTab
                          ? () => _openCardDialog()
                          : () => _openLoanDialog(),
                  tooltip: isCardsTab ? 'Agregar tarjeta' : 'Agregar prestamo',
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
