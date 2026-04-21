import 'package:flutter/material.dart';

import '../data/family_repository.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _repository = FamilyRepository();
  static const List<String> _relationshipOptions = [
    'Esposa',
    'Esposo',
    'Pareja',
    'Hijo',
    'Hija',
    'Padre',
    'Madre',
    'Hermano',
    'Hermana',
    'Otro',
  ];
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  String? _message;
  String? _generatedPassword;

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
    String selectedRelationship = member?['relationship']?.toString() ?? _relationshipOptions.first;
    final linkedEmailController = TextEditingController(
      text: member?['linked_user_email']?.toString() ?? '',
    );
    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(member == null ? 'Nuevo integrante' : 'Editar integrante'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRelationship,
                  decoration: const InputDecoration(labelText: 'Parentesco'),
                  items: _relationshipOptions
                      .map((option) => DropdownMenuItem(value: option, child: Text(option)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedRelationship = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linkedEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo de su cuenta',
                    hintText: 'Opcional, para vincular su usuario',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Contrasena inicial',
                    hintText: 'Opcional. Si la dejas vacia, se genera una temporal',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Guardar')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final normalizedEmail = linkedEmailController.text.trim().isEmpty
          ? null
          : linkedEmailController.text.trim();
      final normalizedPassword = passwordController.text.trim().isEmpty
          ? null
          : passwordController.text.trim();

      Map<String, dynamic> response;
      if (member == null) {
        response = await _repository.createMember(
          name: nameController.text.trim(),
          relationship: selectedRelationship,
          linkedUserEmail: normalizedEmail,
          password: normalizedPassword,
        );
      } else {
        response = await _repository.updateMember(
          id: member['id'] as int,
          name: nameController.text.trim(),
          relationship: selectedRelationship,
          linkedUserEmail: normalizedEmail,
          password: normalizedPassword,
        );
      }
      final generatedPassword = response['generated_password']?.toString();
      final queued = response['queued'] == true;
      setState(() {
        _generatedPassword = generatedPassword;
        if (queued) {
          _message = member == null
              ? 'Integrante guardado en el celular. Se creara la cuenta al sincronizar.'
              : 'Integrante actualizado en el celular. Los cambios se sincronizaran luego.';
        } else if (generatedPassword != null && generatedPassword.isNotEmpty) {
          _message = member == null
              ? 'Integrante agregado y cuenta creada correctamente.'
              : 'Integrante actualizado y cuenta creada correctamente.';
        } else {
          _message = member == null
              ? 'Integrante agregado correctamente.'
              : 'Integrante actualizado correctamente.';
        }
      });
      await _loadData();
    } catch (error) {
      setState(() {
        _generatedPassword = null;
        _message = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _deleteMember(Map<String, dynamic> member) async {
    try {
      await _repository.deleteMember(member['id'] as int);
      setState(() {
        _generatedPassword = null;
        _message = 'Integrante eliminado correctamente';
      });
      await _loadData();
    } catch (error) {
      setState(() {
        _generatedPassword = null;
        _message = error.toString().replaceFirst('Exception: ', '');
      });
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_message!),
                        if ((_generatedPassword ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Clave temporal creada: $_generatedPassword',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ],
                    ),
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
