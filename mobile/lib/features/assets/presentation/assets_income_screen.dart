import 'package:flutter/material.dart';

import '../../../core/widgets/module_placeholder.dart';

class AssetsIncomeScreen extends StatelessWidget {
  const AssetsIncomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Activos e Ingresos',
      description: 'Base para bienes, inventario patrimonial e ingresos familiares.',
    );
  }
}
