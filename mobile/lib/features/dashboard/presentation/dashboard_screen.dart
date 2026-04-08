import 'package:flutter/material.dart';

import '../data/dashboard_repository.dart';
import '../../expenses/presentation/expenses_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repository = DashboardRepository();
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final summary = await _repository.loadSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No hay datos guardados todavia en el celular.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }

    final stats = Map<String, dynamic>.from((_summary?['stats'] as Map?) ?? {});
    final accounts = ((_summary?['accounts'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final recentExpenses = ((_summary?['recentExpenses'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Registro rapido', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        const Text('Usa el microfono para anotar un gasto por voz directamente.'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ExpensesScreen(autoStartVoice: true),
                        ),
                      );
                    },
                    icon: const Icon(Icons.mic_rounded),
                    label: const Text('Audio'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(
                title: 'Saldo disponible',
                value: '\$${((stats['availableBalance'] as num?) ?? 0).toStringAsFixed(2)}',
                icon: Icons.account_balance_wallet_rounded,
              ),
              _StatCard(
                title: 'Deuda total',
                value: '\$${((stats['totalDebt'] as num?) ?? 0).toStringAsFixed(2)}',
                icon: Icons.credit_card_rounded,
              ),
              _StatCard(
                title: 'Gastos del mes',
                value: '\$${((stats['monthlyExpenses'] as num?) ?? 0).toStringAsFixed(2)}',
                icon: Icons.receipt_long_rounded,
              ),
              _StatCard(
                title: 'Ingresos del mes',
                value: '\$${((stats['monthlyIncome'] as num?) ?? 0).toStringAsFixed(2)}',
                icon: Icons.savings_rounded,
              ),
              _StatCard(
                title: 'Activos',
                value: '\$${((stats['totalAssets'] as num?) ?? 0).toStringAsFixed(2)}',
                icon: Icons.home_work_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Saldos en bancos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (accounts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay cuentas registradas para mostrar saldos.'),
              ),
            ),
          ...accounts.map(
            (account) => Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_rounded),
                title: Text(account['bank_name']?.toString() ?? 'Banco'),
                subtitle: Text(
                  '${account['account_type'] ?? 'Cuenta'} · ${account['account_number'] ?? ''}',
                ),
                trailing: Text(
                  '\$${((account['current_balance'] as num?) ?? 0).toStringAsFixed(2)}',
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Ultimos gastos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (recentExpenses.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay gastos recientes para mostrar.'),
              ),
            ),
          ...recentExpenses.map(
            (expense) => Card(
              child: ListTile(
                leading: const Icon(Icons.payments_rounded),
                title: Text(expense['description']?.toString() ?? 'Sin descripcion'),
                subtitle: Text(
                  '${expense['category_name'] ?? 'Sin categoria'} · ${expense['payment_method'] ?? ''} · ${expense['expense_date'] ?? ''}',
                ),
                trailing: Text(
                  '\$${((expense['amount'] as num?) ?? 0).toStringAsFixed(2)}',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
