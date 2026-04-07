import 'package:flutter/material.dart';

import '../data/family_repository.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _repository = FamilyRepository();
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final members = await _repository.loadMembers();
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _members = [];
        _message = null;
        _loading = false;
      });
    }
  }

  Future<void> _openMemberDialog({Map<String, dynamic>? member}) async {
    final nameController = TextEditingController(text: member?['name']?.toString() ?? '');
    final relationshipController = TextEditingController(text: member?['relationship']?.toString() ?? 'Yo');
    final linkedEmailController = TextEditingController(
      text: member?['linked_user_email']?.toString() ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(member == null ? 'Nuevo integrante' : 'Editar integrante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: relationshipController,
              decoration: const InputDecoration(labelText: 'Parentesco'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: linkedEmailController,
              decoration: const InputDecoration(
                labelText: 'Correo de su cuenta',
                hintText: 'Opcional, para vincular su usuario',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Guardar')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (member == null) {
        await _repository.createMember(
          name: nameController.text.trim(),
          relationship: relationshipController.text.trim(),
          linkedUserEmail: linkedEmailController.text.trim().isEmpty
              ? null
              : linkedEmailController.text.trim(),
        );
        _message = 'Integrante agregado correctamente';
      } else {
        await _repository.updateMember(
          id: member['id'] as int,
          name: nameController.text.trim(),
          relationship: relationshipController.text.trim(),
          linkedUserEmail: linkedEmailController.text.trim().isEmpty
              ? null
              : linkedEmailController.text.trim(),
        );
        _message = 'Integrante actualizado correctamente';
      }
      await _loadData();
    } catch (error) {
      setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteMember(Map<String, dynamic> member) async {
    try {
      await _repository.deleteMember(member['id'] as int);
      _message = 'Integrante eliminado correctamente';
      await _loadData();
    } catch (error) {
      setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (_message != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_message!),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_members.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hay integrantes guardados en el celular.'),
                  ),
                ),
              ..._members.map(
                (member) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.family_restroom_rounded),
                    title: Text(member['name']?.toString() ?? ''),
                    subtitle: Text(
                      [
                        member['relationship']?.toString() ?? '',
                        if ((member['linked_user_email']?.toString() ?? '').isNotEmpty)
                          member['linked_user_email']!.toString(),
                      ].where((item) => item.isNotEmpty).join(' · '),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _openMemberDialog(member: member);
                        } else if (value == 'delete') {
                          _deleteMember(member);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            onPressed: _openMemberDialog,
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}
