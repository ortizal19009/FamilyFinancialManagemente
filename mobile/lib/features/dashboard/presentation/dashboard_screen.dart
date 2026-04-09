import 'package:flutter/material.dart';

import '../data/dashboard_repository.dart';
import '../../expenses/presentation/expenses_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.onOpenSection,
  });

  final ValueChanged<String> onOpenSection;

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

  Future<void> _openSection(String section) async {
    widget.onOpenSection(section);
    if (!mounted) return;
    await _loadData();
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
    final cards = ((_summary?['cards'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final loans = ((_summary?['loans'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final recentExpenses = ((_summary?['recentExpenses'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final totalAccountBalance = accounts.fold<double>(
      0,
      (sum, item) => sum + ((item['current_balance'] as num?)?.toDouble() ?? 0),
    );
    final totalCardDebt = cards.fold<double>(
      0,
      (sum, item) => sum + ((item['current_debt'] as num?)?.toDouble() ?? 0),
    );
    final totalLoanDebt = loans.fold<double>(
      0,
      (sum, item) => sum + ((item['pending_debt'] as num?)?.toDouble() ?? 0),
    );

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
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 900 ? 4 : width >= 600 ? 3 : 2;
              final childAspectRatio = width >= 600 ? 1.35 : 1.15;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StatCard(
                    title: 'Saldo disponible',
                    value: '\$${((stats['availableBalance'] as num?) ?? 0).toStringAsFixed(2)}',
                    icon: Icons.account_balance_wallet_rounded,
                    onTap: () => _openSection('banks'),
                  ),
                  _StatCard(
                    title: 'Deuda total',
                    value: '\$${((stats['totalDebt'] as num?) ?? 0).toStringAsFixed(2)}',
                    icon: Icons.credit_card_rounded,
                    onTap: () => _openSection('cards'),
                  ),
                  _StatCard(
                    title: 'Gastos del mes',
                    value: '\$${((stats['monthlyExpenses'] as num?) ?? 0).toStringAsFixed(2)}',
                    icon: Icons.receipt_long_rounded,
                    onTap: () => _openSection('expenses'),
                  ),
                  _StatCard(
                    title: 'Ingresos del mes',
                    value: '\$${((stats['monthlyIncome'] as num?) ?? 0).toStringAsFixed(2)}',
                    icon: Icons.savings_rounded,
                    onTap: () => _openSection('assets'),
                  ),
                  _StatCard(
                    title: 'Activos',
                    value: '\$${((stats['totalAssets'] as num?) ?? 0).toStringAsFixed(2)}',
                    icon: Icons.home_work_rounded,
                    onTap: () => _openSection('assets'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text('Saldos de tus cuentas', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              onTap: () => _openSection('banks'),
              leading: const Icon(Icons.account_balance_wallet_rounded),
              title: const Text('Total en cuentas'),
              subtitle: Text('${accounts.length} cuenta(s) registradas'),
              trailing: Text('\$${totalAccountBalance.toStringAsFixed(2)}'),
            ),
          ),
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
                onTap: () => _openSection('banks'),
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
          Text('Detalle de deuda', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              onTap: () => _openSection('cards'),
              leading: const Icon(Icons.account_tree_rounded),
              title: const Text('Resumen'),
              subtitle: Text(
                'Tarjetas: \$${totalCardDebt.toStringAsFixed(2)} · Prestamos: \$${totalLoanDebt.toStringAsFixed(2)}',
              ),
              trailing: Text('\$${((stats['totalDebt'] as num?) ?? 0).toStringAsFixed(2)}'),
            ),
          ),
          if (cards.isEmpty && loans.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay tarjetas ni prestamos registrados para mostrar detalle.'),
              ),
            ),
          ...cards.map(
            (card) => Card(
              child: ListTile(
                onTap: () => _openSection('cards'),
                leading: const Icon(Icons.credit_card_rounded),
                title: Text(card['card_name']?.toString() ?? 'Tarjeta'),
                subtitle: Text(
                  '${card['bank_name'] ?? 'Sin banco'} · ${card['owner'] ?? 'Sin titular'}',
                ),
                trailing: Text(
                  '\$${((card['current_debt'] as num?) ?? 0).toStringAsFixed(2)}',
                ),
              ),
            ),
          ),
          ...loans.map(
            (loan) => Card(
              child: ListTile(
                onTap: () => _openSection('cards'),
                leading: const Icon(Icons.request_quote_rounded),
                title: Text(loan['description']?.toString() ?? 'Prestamo'),
                subtitle: Text(
                  '${loan['bank_name'] ?? 'Sin banco'} · ${loan['pending_installments'] ?? 0}/${loan['total_installments'] ?? 0} cuotas pendientes',
                ),
                trailing: Text(
                  '\$${((loan['pending_debt'] as num?) ?? 0).toStringAsFixed(2)}',
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
                onTap: () => _openSection('expenses'),
                leading: const Icon(Icons.payments_rounded),
                title: Text(expense['description']?.toString() ?? 'Sin descripcion'),
                subtitle: Text(
                  '${expense['category_name'] ?? 'Sin categoría'} · ${expense['payment_method'] ?? ''} · ${expense['expense_date'] ?? ''}',
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
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Ver detalle',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
