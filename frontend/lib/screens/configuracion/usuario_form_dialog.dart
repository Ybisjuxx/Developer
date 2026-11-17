import 'package:flutter/material.dart';
import '../../services/api_service.dart';

void showUsuarioFormDialog({
  required BuildContext context,
  Map<String, dynamic>? usuarioExistente,
  required VoidCallback onSaved,
}) {
  final bool esEdicion = usuarioExistente != null;
  final usernameCtrl = TextEditingController(text: usuarioExistente?['username'] ?? '');
  final nombreCtrl = TextEditingController(text: usuarioExistente?['nombre_completo'] ?? '');
  final passwordCtrl = TextEditingController();
  String rolSeleccionado = usuarioExistente?['rol'] ?? 'CAJERO';
  bool activo = usuarioExistente?['activo'] ?? true;
  final messenger = ScaffoldMessenger.of(context);
  final primaryColor = Theme.of(context).primaryColor;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  esEdicion ? Icons.manage_accounts : Icons.person_add,
                  color: primaryColor,
                ),
                const SizedBox(width: 8),
                Text(esEdicion ? 'Editar Usuario' : 'Registrar Nuevo Usuario'),
              ],
            ),
            content: Container(
              width: MediaQuery.of(dialogCtx).size.width * 0.9,
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!esEdicion)
                      TextField(
                        controller: usernameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de Usuario (Login) *',
                          prefixIcon: Icon(Icons.account_circle),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Usuario: ${usuarioExistente['username']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre Completo del Operador *',
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: rolSeleccionado,
                      decoration: const InputDecoration(
                        labelText: 'Rol Operativo y Nivel de Acceso *',
                        prefixIcon: Icon(Icons.security),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'CAJERO',
                          child: Text('Cajero (POS, cortes personales)'),
                        ),
                        DropdownMenuItem(
                          value: 'ADMINISTRADOR',
                          child: Text('Administrador (Acceso total, ajustes y bajas)'),
                        ),
                        DropdownMenuItem(
                          value: 'RESPONSABLE_SANITARIO',
                          child: Text('Responsable Sanitario (QFB, controlados y auditoría)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => rolSeleccionado = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: esEdicion
                            ? 'Nueva Contraseña (dejar en blanco para no cambiar)'
                            : 'Contraseña de Acceso *',
                        prefixIcon: const Icon(Icons.lock),
                      ),
                    ),
                    if (esEdicion) ...[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Usuario Activo en el Sistema'),
                        subtitle: Text(
                          activo ? 'Puede iniciar sesión' : 'Acceso revocado temporalmente',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: activo,
                        onChanged: (val) {
                          setDialogState(() => activo = val);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: Text(esEdicion ? 'Actualizar' : 'Crear Usuario'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final nom = nombreCtrl.text.trim();
                  if (nom.isEmpty) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('El nombre completo es requerido.')),
                    );
                    return;
                  }

                  if (!esEdicion) {
                    final uName = usernameCtrl.text.trim();
                    final pass = passwordCtrl.text.trim();
                    if (uName.isEmpty || pass.isEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Usuario y contraseña son obligatorios.')),
                      );
                      return;
                    }

                    try {
                      await ApiService.createUsuario({
                        'username': uName,
                        'nombre_completo': nom,
                        'password': pass,
                        'rol': rolSeleccionado,
                        'activo': true,
                      });
                      if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                      onSaved();
                      if (context.mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Usuario "$uName" registrado exitosamente.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  } else {
                    final updatePayload = <String, dynamic>{
                      'nombre_completo': nom,
                      'rol': rolSeleccionado,
                      'activo': activo,
                    };
                    if (passwordCtrl.text.trim().isNotEmpty) {
                      updatePayload['password'] = passwordCtrl.text.trim();
                    }

                    try {
                      await ApiService.updateUsuario(usuarioExistente['id'], updatePayload);
                      if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                      onSaved();
                      if (context.mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Usuario "${usuarioExistente['username']}" actualizado.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          );
        },
      );
    },
  );
}
