import 'package:flutter/material.dart';

import '../../../core/widgets/module_placeholder.dart';

class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Planificacion',
      description: 'Aqui ira el presupuesto mensual y la comparacion entre planificado y ejecutado.',
    );
  }
}
