import 'package:flutter/material.dart';

import '../../../core/widgets/module_placeholder.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Usuarios Admin',
      description: 'Aqui ira la administracion de usuarios para perfiles con rol admin.',
    );
  }
}
