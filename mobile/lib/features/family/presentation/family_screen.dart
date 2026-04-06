import 'package:flutter/material.dart';

import '../../../core/widgets/module_placeholder.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Familia',
      description: 'Pantalla base para gestionar miembros de familia igual que en web.',
    );
  }
}
