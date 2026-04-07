import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
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
                          Expanded(
                            child: Text(
                              'Tarjetas y prestamos',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _saving ? null : () => _openCardDialog(),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Tarjeta'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _loadedFromCache
                            ? 'Mostrando la ultima informacion guardada localmente.'
                            : 'Datos cargados desde el backend.',
                      ),
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
          Text('Tarjetas', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_cards.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Todavia no hay tarjetas sincronizadas.'),
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
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openCardDialog(card: card);
                    } else if (value == 'delete') {
                      _deleteCard(card);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Prestamos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_loans.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Todavia no hay prestamos sincronizados.'),
              ),
            ),
          ..._loans.map(
            (loan) => Card(
              child: ListTile(
                leading: const Icon(Icons.request_quote_rounded),
                title: Text(loan.description),
                subtitle: Text('${loan.bankName} · ${loan.pendingInstallments}/${loan.totalInstallments} cuotas pendientes'),
                trailing: Column(
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
            ),
          ),
        ],
      ),
    );
  }
}
