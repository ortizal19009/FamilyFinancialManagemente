import 'package:flutter/material.dart';

import '../../../core/widgets/module_placeholder.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Dashboard',
      description: 'Aqui conectaremos el resumen general, ultimos gastos y metricas principales.',
    );
  }
}
