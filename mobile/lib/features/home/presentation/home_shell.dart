import 'dart:async';

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
import '../../investments/presentation/investments_screen.dart';
import '../../planning/presentation/planning_screen.dart';
import '../../settings/presentation/backend_settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.session});

  final UserSession session;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  final _authService = AuthService();
  static const Duration _backgroundRefreshInterval = Duration(seconds: 30);
  int _index = 0;
  int _refreshEpoch = 0;
  bool _wasSyncing = false;
  bool _wasOnline = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppServices.syncService.initialize();
    _wasSyncing = AppServices.syncService.status.isSyncing;
    _wasOnline = AppServices.syncService.status.isOnline;
    AppServices.syncService.addListener(_handleSyncStatusChanged);
    AppServices.dataRefreshNotifier.addListener(_handleExternalRefreshRequested);
    _startBackgroundRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    AppServices.syncService.removeListener(_handleSyncStatusChanged);
    AppServices.dataRefreshNotifier.removeListener(_handleExternalRefreshRequested);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startBackgroundRefresh();
      _syncUpAndDown();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _refreshTimer?.cancel();
    }
  }

  void _handleSyncStatusChanged() {
    final status = AppServices.syncService.status;
    final shouldRefreshCurrentScreen =
        (_wasSyncing && !status.isSyncing) || (!_wasOnline && status.isOnline);
    _wasSyncing = status.isSyncing;
    _wasOnline = status.isOnline;
    if (!shouldRefreshCurrentScreen || !mounted) {
      return;
    }
    setState(() => _refreshEpoch++);
  }

  void _handleExternalRefreshRequested() {
    if (!mounted) {
      return;
    }
    setState(() => _refreshEpoch++);
  }

  void _startBackgroundRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_backgroundRefreshInterval, (_) {
      _syncUpAndDown();
    });
  }

  Future<void> _syncUpAndDown() async {
    await AppServices.syncService.syncPendingOperations();
    if (!mounted) {
      return;
    }
    setState(() => _refreshEpoch++);
  }

  void _openSection(String section) {
    final targetIndex = switch (section) {
      'dashboard' => 0,
      'expenses' => 1,
      'banks' => 2,
      'cards' => 3,
      'planning' => 4,
      'assets' => 5,
      'debtors' => 6,
      'family' => 7,
      'investments' => 8,
      'users' => 9,
      _ => 0,
    };
    if (!mounted) return;
    setState(() => _index = targetIndex.clamp(0, _items.length - 1));
  }

  List<_NavItem> get _items => [
        _NavItem('Dashboard', Icons.space_dashboard_rounded, DashboardScreen(onOpenSection: _openSection)),
        const _NavItem('Gastos', Icons.receipt_long_rounded, ExpensesScreen()),
        const _NavItem('Bancos', Icons.account_balance_rounded, BanksScreen()),
        const _NavItem('Tarjetas', Icons.credit_card_rounded, CardsLoansScreen()),
        const _NavItem('Planificacion', Icons.calendar_month_rounded, PlanningScreen()),
        const _NavItem('Activos', Icons.home_work_rounded, AssetsIncomeScreen()),
        const _NavItem('Deudores', Icons.group_rounded, DebtorsScreen()),
        const _NavItem('Familia', Icons.family_restroom_rounded, FamilyScreen()),
        const _NavItem('Inversiones', Icons.trending_up_rounded, InvestmentsScreen()),
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
            return Text(item.label);
          },
        ),
        actions: [
          AnimatedBuilder(
            animation: AppServices.syncService,
            builder: (context, _) {
              final status = AppServices.syncService.status;
              final isEnabled = !status.isSyncing;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: status.isOnline ? Colors.green.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status.isOnline ? 'ON' : 'OFF',
                      style: TextStyle(
                        color: status.isOnline ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Recargar y sincronizar',
                    onPressed: isEnabled
                        ? _syncUpAndDown
                        : null,
                    icon: status.isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded),
                  ),
                ],
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
              leading: const Icon(Icons.settings_rounded),
              title: const Text('Configuracion backend'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BackendSettingsScreen(),
                  ),
                );
              },
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
      body: KeyedSubtree(
        key: ValueKey('home-screen-$_index-$_refreshEpoch'),
        child: item.screen,
      ),
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
