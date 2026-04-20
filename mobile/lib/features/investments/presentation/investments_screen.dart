import 'package:flutter/material.dart';

import '../../family/data/family_repository.dart';
import '../data/mobile_investments_repository.dart';
import '../domain/investment_summary.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  final _repository = MobileInvestmentsRepository();
  final _familyRepository = FamilyRepository();

  List<InvestmentSummary> _investments = [];
  List<String> _ownerOptions = [];
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final investments = await _repository.loadInvestments();
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
    if (!mounted) {
      return;
    }
    setState(() {
      _investments = investments;
      _ownerOptions = ownerOptions;
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
    setDialogState(() => controller.text = _formatDate(pickedDate));
  }

  Future<void> _openInvestmentDialog({InvestmentSummary? investment}) async {
    final institutionController = TextEditingController(text: investment?.institution ?? '');
    final titleController = TextEditingController(text: investment?.title ?? '');
    final notesController = TextEditingController(text: investment?.notes ?? '');
    final investedAmountController = TextEditingController(
      text: investment == null ? '0' : investment.investedAmount.toStringAsFixed(2),
    );
    final currentValueController = TextEditingController(
      text: investment == null ? '0' : investment.currentValue.toStringAsFixed(2),
    );
    final returnRateController = TextEditingController(
      text: investment?.expectedReturnRate?.toStringAsFixed(2) ?? '',
    );
    final startDateController = TextEditingController(text: investment?.startDate ?? _formatDate(DateTime.now()));
    final endDateController = TextEditingController(text: investment?.endDate ?? '');
    String selectedType = investment?.investmentType ?? 'Cooperativa';
    String selectedStatus = investment?.status ?? 'activa';
    String? selectedOwner = investment?.owner;
    final ownerChoices = {
      ..._ownerOptions,
      if ((investment?.owner ?? '').trim().isNotEmpty) investment!.owner!.trim(),
    }.toList()
      ..sort();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(investment == null ? 'Nueva inversion' : 'Editar inversion'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: institutionController,
                  decoration: const InputDecoration(labelText: 'Institucion'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    'Cooperativa',
                    'Seguro',
                    'Negocio',
                    'Certificado',
                    'Otro',
                  ]
                      .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedType = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Nombre inversion'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: selectedOwner,
                  decoration: const InputDecoration(labelText: 'Propietario'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sin propietario'),
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
                  controller: investedAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Monto invertido'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: currentValueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor actual'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: returnRateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Rentabilidad esperada %'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    'activa',
                    'cerrada',
                    'pausada',
                  ]
                      .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedStatus = value);
                  },
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
                const SizedBox(height: 12),
                TextField(
                  controller: endDateController,
                  readOnly: true,
                  onTap: () => _pickDate(context, endDateController, setDialogState),
                  decoration: const InputDecoration(
                    labelText: 'Fecha fin',
                    suffixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notas'),
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
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final investedAmount = double.tryParse(investedAmountController.text.trim()) ?? 0;
      final currentValue = double.tryParse(currentValueController.text.trim()) ?? investedAmount;
      final expectedReturnRate = double.tryParse(returnRateController.text.trim());

      if (investment == null) {
        await _repository.createInvestment(
          institution: institutionController.text.trim(),
          investmentType: selectedType,
          title: titleController.text.trim(),
          owner: selectedOwner,
          investedAmount: investedAmount,
          currentValue: currentValue,
          expectedReturnRate: expectedReturnRate,
          startDate: startDateController.text.trim().isEmpty ? null : startDateController.text.trim(),
          endDate: endDateController.text.trim().isEmpty ? null : endDateController.text.trim(),
          status: selectedStatus,
          notes: notesController.text.trim(),
        );
        _message = 'Inversion guardada correctamente';
      } else {
        await _repository.updateInvestment(
          id: investment.id,
          institution: institutionController.text.trim(),
          investmentType: selectedType,
          title: titleController.text.trim(),
          owner: selectedOwner,
          investedAmount: investedAmount,
          currentValue: currentValue,
          expectedReturnRate: expectedReturnRate,
          startDate: startDateController.text.trim().isEmpty ? null : startDateController.text.trim(),
          endDate: endDateController.text.trim().isEmpty ? null : endDateController.text.trim(),
          status: selectedStatus,
          notes: notesController.text.trim(),
        );
        _message = 'Inversion actualizada correctamente';
      }
      await _loadData();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteInvestment(InvestmentSummary investment) async {
    try {
      await _repository.deleteInvestment(investment.id);
      _message = 'Inversion eliminada correctamente';
      await _loadData();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  double get _totalInvested =>
      _investments.fold(0, (sum, item) => sum + item.investedAmount);

  double get _totalCurrentValue =>
      _investments.fold(0, (sum, item) => sum + item.currentValue);

  double get _totalProfitLoss =>
      _investments.fold(0, (sum, item) => sum + item.profitLoss);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (_message != null) ...[
                Text(_message!),
                const SizedBox(height: 12),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 700;
                  return GridView.count(
                    crossAxisCount: isWide ? 3 : 1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: isWide ? 1.8 : 3.2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _InvestmentStatCard(
                        title: 'Capital invertido',
                        value: '\$${_totalInvested.toStringAsFixed(2)}',
                      ),
                      _InvestmentStatCard(
                        title: 'Valor actual',
                        value: '\$${_totalCurrentValue.toStringAsFixed(2)}',
                      ),
                      _InvestmentStatCard(
                        title: 'Rendimiento',
                        value: '\$${_totalProfitLoss.toStringAsFixed(2)}',
                        valueColor: _totalProfitLoss >= 0 ? Colors.green : Colors.red,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              if (_investments.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Todavia no hay inversiones guardadas en el celular.'),
                  ),
                ),
              ..._investments.map(
                (investment) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.trending_up_rounded),
                    title: Text(investment.title),
                    subtitle: Text(
                      '${investment.investmentType} · ${investment.institution} · ${investment.owner ?? 'Sin propietario'}',
                    ),
                    trailing: SizedBox(
                      width: 182,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Text(
                              '\$${investment.currentValue.toStringAsFixed(2)}',
                              textAlign: TextAlign.end,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Editar',
                            onPressed: () => _openInvestmentDialog(investment: investment),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: () => _deleteInvestment(investment),
                            icon: const Icon(Icons.delete_outline_rounded),
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
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            onPressed: () => _openInvestmentDialog(),
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

class _InvestmentStatCard extends StatelessWidget {
  const _InvestmentStatCard({
    required this.title,
    required this.value,
    this.valueColor,
  });

  final String title;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: valueColor),
            ),
          ],
        ),
      ),
    );
  }
}
