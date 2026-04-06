import 'package:flutter/material.dart';

import '../../../core/widgets/module_placeholder.dart';

class DebtorsScreen extends StatelessWidget {
  const DebtorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Deudores',
      description: 'Aqui podras consultar, crear y actualizar deudores desde el movil.',
    );
  }
}
