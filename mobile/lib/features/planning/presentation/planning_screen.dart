import 'package:flutter/material.dart';

import '../data/planning_repository.dart';
import '../../expenses/domain/expense_category.dart';

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  final _repository = PlanningRepository();
  List<Map<String, dynamic>> _plans = [];
  List<ExpenseCategory> _categories = [];
  bool _loading = true;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final categories = await _repository.loadCategories();
      final plans = await _repository.loadPlanning(month: _month, year: _year);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _plans = plans;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openPlanDialog({Map<String, dynamic>? plan}) async {
    if (_categories.isEmpty) {
      setState(() => _message = 'No hay categorias disponibles');
      return;
    }

    int selectedCategory = (plan?['category_id'] as int?) ?? _categories.first.id;
    final amountController = TextEditingController(
      text: ((plan?['planned_amount'] as num?) ?? 0).toString(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(plan == null ? 'Nuevo presupuesto' : 'Editar presupuesto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: _categories
                      .map((category) => DropdownMenuItem(value: category.id, child: Text(category.name)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedCategory = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Monto planificado'),
                ),
              ],
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
      final amount = double.tryParse(amountController.text.trim()) ?? 0;
      if (plan == null) {
        await _repository.createPlan(
          categoryId: selectedCategory,
          plannedAmount: amount,
          month: _month,
          year: _year,
        );
        _message = 'Presupuesto guardado correctamente';
      } else {
        await _repository.updatePlan(
          id: plan['id'] as int,
          categoryId: selectedCategory,
          plannedAmount: amount,
          month: _month,
          year: _year,
        );
        _message = 'Presupuesto actualizado correctamente';
      }
      await _loadData();
    } catch (error) {
      setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deletePlan(Map<String, dynamic> plan) async {
    try {
      await _repository.deletePlan(plan['id'] as int);
      _message = 'Presupuesto eliminado correctamente';
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

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _month,
                          decoration: const InputDecoration(labelText: 'Mes'),
                          items: List.generate(
                            12,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('Mes ${index + 1}'),
                            ),
                          ),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _month = value);
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: _year.toString()),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Anio'),
                          onSubmitted: (value) {
                            final parsed = int.tryParse(value);
                            if (parsed == null) return;
                            setState(() => _year = parsed);
                            _loadData();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: Text('Planificacion mensual', style: Theme.of(context).textTheme.titleLarge)),
                      FilledButton.icon(
                        onPressed: () => _openPlanDialog(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Agregar'),
                      ),
                    ],
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
          if (_plans.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay presupuestos cargados para este periodo.'),
              ),
            ),
          ..._plans.map(
            (plan) => Card(
              child: ListTile(
                title: Text(plan['category_name']?.toString() ?? 'Sin categoria'),
                subtitle: Text(
                  'Planificado: \$${((plan['planned_amount'] as num?) ?? 0).toStringAsFixed(2)} · Ejecutado: \$${((plan['actual_amount'] as num?) ?? 0).toStringAsFixed(2)}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openPlanDialog(plan: plan);
                    } else if (value == 'delete') {
                      _deletePlan(plan);
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
    );
  }
}
