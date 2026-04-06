import 'package:flutter/material.dart';

class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(description),
              const SizedBox(height: 16),
              const Text(
                'Base movil lista. Aqui vamos migrando el CRUD y las vistas desde la version web.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
