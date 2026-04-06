import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../admin/presentation/admin_users_screen.dart';
import '../../assets/presentation/assets_income_screen.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/domain/user_session.dart';
import '../../auth/presentation/login_screen.dart';
import '../../banks/presentation/banks_screen.dart';
import '../../cards/presentation/cards_loans_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../debtors/presentation/debtors_screen.dart';
import '../../expenses/presentation/expenses_screen.dart';
import '../../family/presentation/family_screen.dart';
import '../../planning/presentation/planning_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.session});

  final UserSession session;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _authService = AuthService();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    AppServices.syncService.initialize();
  }

  List<_NavItem> get _items => [
        const _NavItem('Dashboard', Icons.space_dashboard_rounded, DashboardScreen()),
        const _NavItem('Gastos', Icons.receipt_long_rounded, ExpensesScreen()),
        const _NavItem('Bancos', Icons.account_balance_rounded, BanksScreen()),
        const _NavItem('Tarjetas', Icons.credit_card_rounded, CardsLoansScreen()),
        const _NavItem('Planificacion', Icons.calendar_month_rounded, PlanningScreen()),
        const _NavItem('Activos', Icons.home_work_rounded, AssetsIncomeScreen()),
        const _NavItem('Deudores', Icons.group_rounded, DebtorsScreen()),
        const _NavItem('Familia', Icons.family_restroom_rounded, FamilyScreen()),
        if (widget.session.role == 'admin')
          const _NavItem('Usuarios', Icons.admin_panel_settings_rounded, AdminUsersScreen()),
      ];

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_index];

    return Scaffold(
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: AppServices.syncService,
          builder: (context, _) {
            final status = AppServices.syncService.status;
            final subtitle = status.pendingCount > 0
                ? 'Pendientes: ${status.pendingCount}'
                : (status.isOnline ? 'En linea' : 'Sin acceso al backend');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
        actions: [
          AnimatedBuilder(
            animation: AppServices.syncService,
            builder: (context, _) {
              final status = AppServices.syncService.status;
              return IconButton(
                tooltip: 'Sincronizar',
                onPressed: status.isSyncing
                    ? null
                    : () => AppServices.syncService.syncPendingOperations(),
                icon: status.isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(widget.session.fullName),
              accountEmail: Text(widget.session.email),
              currentAccountPicture: CircleAvatar(
                child: Text(
                  widget.session.fullName.isNotEmpty
                      ? widget.session.fullName.characters.first.toUpperCase()
                      : 'F',
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final navItem = _items[index];
                  return ListTile(
                    leading: Icon(navItem.icon),
                    title: Text(navItem.label),
                    selected: index == _index,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _index = index);
                    },
                  );
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Cerrar sesion'),
              onTap: _logout,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      body: item.screen,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index > 3 ? 0 : _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Gastos',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_rounded),
            label: 'Bancos',
          ),
          NavigationDestination(
            icon: Icon(Icons.credit_card_rounded),
            label: 'Tarjetas',
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.screen);

  final String label;
  final IconData icon;
  final Widget screen;
}
