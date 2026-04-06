import 'package:flutter/material.dart';

import '../../../core/widgets/module_placeholder.dart';

class CardsLoansScreen extends StatelessWidget {
  const CardsLoansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Tarjetas y Prestamos',
      description: 'Pantalla base para tarjetas, prestamos y seguimiento de deuda desde el movil.',
    );
  }
}
