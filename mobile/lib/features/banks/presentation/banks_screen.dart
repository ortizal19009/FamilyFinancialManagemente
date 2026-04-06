import 'package:flutter/material.dart';

import '../../../core/widgets/module_placeholder.dart';

class BanksScreen extends StatelessWidget {
  const BanksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Bancos y Cuentas',
      description: 'Aqui migramos bancos, cuentas, editar, cerrar cuenta y gestion relacionada.',
    );
  }
}
