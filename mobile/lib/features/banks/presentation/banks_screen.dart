import 'package:flutter/material.dart';

import '../../family/data/family_repository.dart';
import '../data/mobile_banks_repository.dart';
import '../domain/bank_models.dart';

class BanksScreen extends StatefulWidget {
  const BanksScreen({super.key});

  @override
  State<BanksScreen> createState() => _BanksScreenState();
}

class _BanksScreenState extends State<BanksScreen> {
  final _repository = MobileBanksRepository();
  final _familyRepository = FamilyRepository();
  final _tabController = ValueNotifier<int>(0);

  List<BankSummary> _banks = [];
  List<BankAccountSummary> _accounts = [];
  List<String> _ownerOptions = [];
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
    List<String> ownerOptions = _ownerOptions;
    try {
      final members = await _familyRepository.loadMembers();
      ownerOptions = members
          .map((item) => item['name']?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _banks = snapshot.banks;
      _accounts = snapshot.accounts;
      _ownerOptions = ownerOptions;
      _loadedFromCache = snapshot.loadedFromCache;
      _loading = false;
    });
  }

  Future<void> _openBankDialog({BankSummary? bank}) async {
    final nameController = TextEditingController(text: bank?.name ?? '');
    final descriptionController = TextEditingController(text: bank?.description ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(bank == null ? 'Nuevo banco' : 'Editar banco'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre del banco'),
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(bank == null ? 'Agregar' : 'Guardar'),
            ),
          ],
        );
      },
    );

    if (result != true) {
      return;
    }

    final name = nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _message = 'El nombre del banco es obligatorio');
      return;
    }

    setState(() => _saving = true);
    try {
      if (bank == null) {
        await _repository.createBank(
          name: name,
          description: descriptionController.text.trim(),
        );
        _message = 'Banco agregado correctamente';
      } else {
        await _repository.updateBank(
          bankId: bank.id,
          name: name,
          description: descriptionController.text.trim(),
        );
        _message = 'Banco actualizado correctamente';
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

  Future<void> _deleteBank(BankSummary bank) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar banco'),
        content: Text('Se eliminara "${bank.name}" si no tiene registros asociados.'),
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
      await _repository.deleteBank(bank.id);
      _message = 'Banco eliminado correctamente';
      await _loadData();
    } catch (error) {
      _message = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openAccountDialog({BankAccountSummary? account}) async {
    if (_banks.isEmpty) {
      setState(() => _message = 'Primero debes registrar un banco');
      return;
    }

    int selectedBankId = account?.bankId ?? _banks.first.id;
    String selectedType = account?.accountType ?? 'Ahorros';
    String? selectedOwner = account?.owner;
    final numberController = TextEditingController(text: account?.accountNumber ?? '');
    final balanceController = TextEditingController(
      text: account == null ? '0' : account.currentBalance.toStringAsFixed(2),
    );
    final ownerChoices = {
      ..._ownerOptions,
      if ((account?.owner ?? '').trim().isNotEmpty) account!.owner!.trim(),
    }.toList()
      ..sort();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(account == null ? 'Nueva cuenta' : 'Editar cuenta'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedBankId,
                      decoration: const InputDecoration(labelText: 'Banco'),
                      items: _banks
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
                      controller: numberController,
                      decoration: const InputDecoration(labelText: 'Numero de cuenta'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'Tipo de cuenta'),
                      items: const [
                        DropdownMenuItem(value: 'Ahorros', child: Text('Ahorros')),
                        DropdownMenuItem(value: 'Corriente', child: Text('Corriente')),
                        DropdownMenuItem(value: 'Digital', child: Text('Digital')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedOwner,
                      decoration: const InputDecoration(labelText: 'Titular'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Sin titular'),
                        ),
                        ...ownerChoices.map(
                          (owner) => DropdownMenuItem<String?>(
                            value: owner,
                            child: Text(owner),
                          ),
                        ),
                      ],
                      onChanged: (value) => setDialogState(() => selectedOwner = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: balanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Saldo actual'),
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
                  child: Text(account == null ? 'Agregar' : 'Guardar'),
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

    final accountNumber = numberController.text.trim();
    if (accountNumber.isEmpty) {
      setState(() => _message = 'El numero de cuenta es obligatorio');
      return;
    }

    setState(() => _saving = true);
    try {
      if (account == null) {
        await _repository.createAccount(
          bankId: selectedBankId,
          accountNumber: accountNumber,
          accountType: selectedType,
          owner: selectedOwner,
          currentBalance: double.tryParse(balanceController.text.trim()) ?? 0,
        );
        _message = 'Cuenta guardada correctamente. Si ya existia, se fusiono.';
      } else {
        await _repository.updateAccount(
          accountId: account.id,
          bankId: selectedBankId,
          accountNumber: accountNumber,
          accountType: selectedType,
          owner: selectedOwner,
          currentBalance: double.tryParse(balanceController.text.trim()) ?? 0,
        );
        _message = 'Cuenta actualizada correctamente';
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

  Future<void> _deleteAccount(BankAccountSummary account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: Text('Se eliminara la cuenta ${account.accountNumber} si no tiene gastos asociados.'),
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
      await _repository.deleteAccount(account.id);
      _message = 'Cuenta eliminada correctamente';
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
                        Tab(text: 'Bancos', icon: Icon(Icons.account_balance_rounded)),
                        Tab(text: 'Cuentas', icon: Icon(Icons.savings_rounded)),
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
                          if (_banks.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Todavia no hay bancos guardados en el celular.'),
                              ),
                            ),
                          ..._banks.map(
                            (bank) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.account_balance_rounded),
                                title: Text(bank.name),
                                subtitle: Text(
                                  bank.description?.isNotEmpty == true ? bank.description! : 'Sin descripcion',
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openBankDialog(bank: bank);
                                    } else if (value == 'delete') {
                                      _deleteBank(bank);
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
                        ],
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        children: [
                          if (_accounts.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Todavia no hay cuentas guardadas en el celular.'),
                              ),
                            ),
                          ..._accounts.map(
                            (account) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.savings_rounded),
                                title: Text('${account.bankName} · ${account.accountNumber}'),
                                subtitle: Text(
                                  '${account.accountType ?? 'Cuenta'} · ${account.owner ?? 'Sin propietario'}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('\$${account.currentBalance.toStringAsFixed(2)}'),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _openAccountDialog(account: account);
                                        } else if (value == 'delete') {
                                          _deleteAccount(account);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                                        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                                      ],
                                    ),
                                  ],
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
                final isBanksTab = activeTab == 0;
                return FloatingActionButton(
                  onPressed: _saving
                      ? null
                      : isBanksTab
                          ? () => _openBankDialog()
                          : () => _openAccountDialog(),
                  tooltip: isBanksTab ? 'Agregar banco' : 'Agregar cuenta',
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
